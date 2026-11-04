// $License: NOLICENSE
//--------------------------------------------------------------------------------
/**
  @file $relPath
  @copyright $copyright
  @author Rustam Yusupov Sensors.Modules.Systems

*/

//--------------------------------------------------------------------------------
// Libraries used (#uses)
#uses "confOperations"
#uses "helper"

//--------------------------------------------------------------------------------
// Variables and Constants
private const string ARCHIVE_GROUPS_FILE_PATH = _PROJ_PATH + SOURCE_REL_PATH + "ArchiveGroups.csv";
private const int MIN_ARCHIVE_COLUMNS_NUMBER = 2;

private const string NGA_BACKEND_DP = "_NGA_B_InfluxDB";

//--------------------------------------------------------------------------------
//@public members
//--------------------------------------------------------------------------------

/*
  Functions reads data from file
*/
public int Archiving_getArchivingInfo(dyn_dyn_string &archiveGroupsData, string &message)
{
  archiveGroupsData.clear();
  dyn_string archiveGroupsInfo = readFileANSI(ARCHIVE_GROUPS_FILE_PATH, true);
  int counter = 0;
  if (archiveGroupsInfo.count() == 0)
  {
    message = "Считывание информации об архивировании: файл не считан либо не заполнен";
    return -1;
  }
  for (int i = 1; i <= archiveGroupsInfo.count(); i++)
  {
    dyn_string dsTmp = strsplit(archiveGroupsInfo[i], ";");
    if (dsTmp.count() < MIN_ARCHIVE_COLUMNS_NUMBER)
      continue;
    else
    {
      dynAppend(archiveGroupsData, dsTmp);
      counter++;
    }
  }
  message = "Считывание информации об архивировании: " + (counter == archiveGroupsInfo.count() ? "успешно" : "считано " + counter + " строк из " + archiveGroupsInfo.count());
  return counter == archiveGroupsInfo.count() ? 1 : -2;
}


// ------Добавить архивы
public int Archiving_addArchiveToValue(string dpe, string archiveGroup, string &message)
{
  if (archiveGroup.isEmpty())
  {
    message = dpe + ": передана пустая архивная группа, архивация не добавлена";
    return -1;
  }
  int res;
  string systemName = dpSubStr(dpe, DPSUB_SYS);
  if (!confOperations_dpExists(systemName + "_NGA_G_" + archiveGroup, "_NGA_Group"))
  {
    res = confOperations_createNgaArchiveGroup(archiveGroup, systemName + NGA_BACKEND_DP, message);
    if (res < 0)
      return res;
  }
  if (!confOperations_dpExists(systemName + "_NGA_G_" + archiveGroup + "_2", "_NGA_Group"))
  {
    res = confOperations_createNgaArchiveGroup(archiveGroup + "_2", systemName + NGA_BACKEND_DP + "_2", message);
    if (res < 0)
      return res;
  }
  if (doesArchiveMatches(dpe, archiveGroup))
  {
    message = dpe + ": уже привязана правильная архивная группа " + archiveGroup + " для ТД " + dpe;
    return 1;
  }
  return confOperations_dpSetNgaArchive(dpe, archiveGroup, message);
}


// Функция проверяет, совпадают ли конфиги
private bool doesArchiveMatches(string dpe, string archiveGroup)
{
  if (confOperations_doesConfExist(dpe, "archive") && confOperations_dpExists(confOperations_getConfValue(dpe, ":_archive.1._class"))) // Тот случай, когда нужен dpExists
  {
    string existingArchiveGroup = confOperations_getConfValue(dpe, ":_archive.1._class");
    existingArchiveGroup = dpSubStr(existingArchiveGroup, DPSUB_DP);
    existingArchiveGroup.replace("_NGA_G_", "");
    return existingArchiveGroup == archiveGroup;
  }
  return false;
}

public bool Archiving_needArchiveForSumSignal(string dpType, string dpEl, dyn_mixed sumSignals)
{
  for (int i = 1; i <= sumSignals.count(); i++)
  {
    mapping m = sumSignals[i];
    if (m.contains("dpType") && m.contains("dpElement") && m.contains("needArchive") && (m["dpType"] == dpType || m["dpType"] == "*") && m["dpElement"] == dpEl)
      return m["needArchive"];
  }
  // По умолчанию архив для суммарного сигнала нужен
  return true;
}


// Функция ищет архивную группу в файле МН ТУ Маск
public string Archiving_getArchiveGroupForDPE(string dpeWithSystem, dyn_dyn_string archiveGroups)
{
  string archiveGroup = "";
  string dpeWithoutSystem = dpSubStr(dpeWithSystem, DPSUB_DP_EL);
  for (int i = 1; i <= archiveGroups.count(); i++)
  {
    if ((patternMatch(archiveGroups[i][1], dpeWithSystem) || patternMatch(archiveGroups[i][1], dpeWithoutSystem)) && archiveGroups[i].count() == 2)
      return archiveGroups[i][2];
  }
  return "";
}


