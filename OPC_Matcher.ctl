// $License: NOLICENSE
//--------------------------------------------------------------------------------
/**
  @file $relPath
  @copyright $copyright
  @author Rustam.Yusupov
*/

//--------------------------------------------------------------------------------
// Libraries used (#uses)
#uses "helper"
#uses "confOperations"
#uses "CNS_Helper"
//--------------------------------------------------------------------------------
// Variables and Constants

// Общая для всех тегов начало, которое следует удалить
private const dyn_string OPC_INIT_PARTS = makeDynString("AK.VSMN.R_Ner.", "AK.VSMN.R_Len.", "AK.VSMN.MN_KT.");

// Путь до файла, в котором содержится сопоставление части OPC-тега и родительской ТД
private const string OPC_MATCH_PARENT_DPS_FILE = SUBPROJ_PATH + SOURCE_REL_PATH + "CNS/OPCMatchDP/opcMatchParentDPs.csv";
private dyn_dyn_string ddsOPCMatchParentDPs;
// Путь до файла, в котором описаны правила преобразования OPC тега в DP
private const string OPC_MATCH_DPS_RULES_FILE = SUBPROJ_PATH + SOURCE_REL_PATH + "CNS/OPCMatchDP/opcMatchDPsRules.json";
private mapping mOPCMatchDPsRules;
// Путь до файла, в котором описаны правила преобразования OPC тега в DPE
private const string OPC_MATCH_DPES_RULES_FILE = SUBPROJ_PATH + SOURCE_REL_PATH + "CNS/OPCMatchDP/opcMatchDPEsRules.json";
private mapping mOPCMatchDPEsRules;
// Маппинг для поиска DPE по адресу, где
// Ключ - базированная ТД, значение - массив потенциальных DPE для сопоставления адресов
private mapping mDP_Filter;

//--------------------------------------------------------------------------------
//@public members
//--------------------------------------------------------------------------------

// Функция считывает информацию из source-файлов
public int OPC_MATCHING_readInfoFromSourceFiles(string &message)
{
  dyn_string dsOPCMatchDPsLines = readFileANSI(OPC_MATCH_PARENT_DPS_FILE, false);
  if (dsOPCMatchDPsLines.count() == 0)
  {
    message = OPC_MATCH_PARENT_DPS_FILE + ": файл отсутствует либо не заполнен";
    return -1;
  }
  for (int i = 1; i <= dsOPCMatchDPsLines.count(); i++)
  {
    dyn_string dsOPCMatchDPsLine = strsplit(dsOPCMatchDPsLines[i], ";");
    if (dsOPCMatchDPsLine.count() == 3)
      ddsOPCMatchParentDPs.append(dsOPCMatchDPsLine);
    else
      DebugN(OPC_MATCH_PARENT_DPS_FILE + ": некорретная информация в строке " + i);
  }


  string jsonOPCDPsRules;
  fileToString(OPC_MATCH_DPS_RULES_FILE, jsonOPCDPsRules, "ANSI1251");
  if (jsonOPCDPsRules.isEmpty())
  {
    message = OPC_MATCH_DPS_RULES_FILE + ": файл отсутствует либо не заполнен";
    return -2;
  }
  mOPCMatchDPsRules = jsonDecode(jsonOPCDPsRules);
  if (mOPCMatchDPsRules.count() == 0)
  {
    message = OPC_MATCH_DPS_RULES_FILE + ": файл отсутствует либо не заполнен";
    return -2;
  }


  string jsonOPCDPEsRules;
  fileToString(OPC_MATCH_DPES_RULES_FILE, jsonOPCDPEsRules, "ANSI1251");
  if (jsonOPCDPEsRules.isEmpty())
  {
    message = OPC_MATCH_DPES_RULES_FILE + ": файл отсутствует либо не заполнен";
    return -3;
  }
  mOPCMatchDPEsRules = jsonDecode(jsonOPCDPEsRules);
  for (int i = 0; i < mOPCMatchDPEsRules.count(); i++)
  {
    mapping m = mOPCMatchDPEsRules.valueAt(i);
    mapping newM = makeMapping();
    for (int j = 0; j < m.count(); j++)
    {
      string key = m.keyAt(j);
      newM.insert(key.toUpper(), m.valueAt(j));
    }
    mOPCMatchDPEsRules[mOPCMatchDPEsRules.keyAt(i)] = newM;
  }
  if (mOPCMatchDPEsRules.count() == 0)
  {
    message = OPC_MATCH_DPES_RULES_FILE + ": файл отсутствует либо не заполнен";
    return -3;
  }

 /* dyn_string dsOPCReplaceDPsLines = readFileANSI(OPC_REPLACE_FILE, false);
  if (dsOPCMatchDPsLines.count() == 0)
  {
    message = OPC_REPLACE_FILE + ": файл отсутствует либо не заполнен";
    return -4;
  }
  for (int i = 1; i <= dsOPCReplaceDPsLines.count(); i++)
  {
    dyn_string dsOPCReplaceDPsLine = strsplit(dsOPCReplaceDPsLines[i], ";");
    if (dsOPCReplaceDPsLine.count() == 2)
      mOPCReplaceDPs.insert(dsOPCReplaceDPsLine[1], dsOPCReplaceDPsLine[2]);
    else
      DebugN(OPC_MATCH_PARENT_DPS_FILE + ": некорретная информация в строке " + i);
  }*/
  return 0;
}

// Поиск соотвествующей OPC-тегу точки данных
// -1 - не найдена ТД (невозможно найти в файле сопоставлений)
// -3 - не найдено сопоставление DPE
public int OPC_MATCHING_getDPByOPCTag(string opcTag, string &baseDP, string &dp, string &dpType, string &message)
{
  baseDP = "";
  dp = "";
  dpType = "";
  message = "";

  // Удаление начальной части тега
  for (int i = 1; i <= OPC_INIT_PARTS.count(); i++)
    opcTag.replace(OPC_INIT_PARTS[i], "");

  // Поиск родительской ТД
  bool forElse = true;
  for (int i = 1; i <= ddsOPCMatchParentDPs.count(); i++)
  {
    if (opcTag.startsWith(ddsOPCMatchParentDPs[i][1] + "."))
    {
      dp = ddsOPCMatchParentDPs[i][2];
      dpType = ddsOPCMatchParentDPs[i][3];
      opcTag.replace(ddsOPCMatchParentDPs[i][1] + ".", "");
      baseDP = dp;
      forElse = false;
      break;
    }
  }
  string originalParentDP = dp;
//    DebugN(dp, dpType);
  if (forElse)
  {
    message += "отсутствует информация в файле " + OPC_MATCH_PARENT_DPS_FILE;
    return -1;
  }

  // Формирование оставшиейся части DP по правилам
  forElse = true;
  dyn_string dsOPCTagParts = opcTag.split(".");
  // Оставшаяся часть OPC-тега для преобразования в DPE
  string opcDPEPart = "";
  for (int i = 1; i <= dsOPCTagParts.count(); i++)
  {
    // Флаг конца части OPC-тега, соответствующего DP-части (далее DPE-часть)
    bool endDPPartFlag = true;
    for (int j = 0; j < mOPCMatchDPsRules.count(); j++)
    {
      if (patternMatch(mOPCMatchDPsRules.keyAt(j) + "*", dsOPCTagParts[i]))
      {
        endDPPartFlag = false;
        dyn_mapping functions = mOPCMatchDPsRules.valueAt(j);
				for (int k = 1; k <= functions.count(); k++)
				{
					int res = 0;
          string mes;
          if (isFunctionDefined("OPC_MATCHING_dp_" + functions[k].keyAt(0)))
          {
            callFunction("OPC_MATCHING_dp_" + functions[k].keyAt(0), opcTag, dsOPCTagParts[i], originalParentDP, dp, dpType, functions[k].valueAt(0), res, mes);
//             DebugN(mes);
            //TODO change <= =
            if (res < 0)
            {
              message += mes;
              return -5;
            }
          }
				}
      }
    }
    // Обработка конца части OPC-тега, соответствующего DP-части (далее DPE-часть)
    if (endDPPartFlag)
    {
      opcDPEPart = dsOPCTagParts[i];
      for (int j = i + 1; j <= dsOPCTagParts.count(); j++)
        opcDPEPart += "." + dsOPCTagParts[j];
      break;
    }
  }
  // имя ТД в верхнй регистр
  dp = dp.toUpper();
  baseDP = dp;
  // Замена найденного имени ТД на правильное, если его невозможно вытащить алгоритмом
/*  if (mOPCReplaceDPs.contains(dp))
    dp = mOPCReplaceDPs[dp];*/
//   DebugN(opcDPEPart);
//   DebugN(dpType);

  // Формирование DPE
  string _opcDPEPart = opcDPEPart.toUpper();
  if (mOPCMatchDPEsRules.contains(dpType) && mOPCMatchDPEsRules[dpType].contains(_opcDPEPart))
  {
    dyn_mixed opcDPEInfo = mOPCMatchDPEsRules[dpType][_opcDPEPart];
//     DebugN(opcDPEInfo, opcDPEInfo.count());
    // Если в массиве один элемент, преобразуем в DPE, если больше, выполняем функции
    dp += "." + opcDPEInfo[1];
    if (opcDPEInfo.count() == 2)
    {
      int res = 0;
      string mes = "";
      mapping functions = opcDPEInfo[2];
      for (int j = 0; j < functions.count(); j++)
      {
        if (isFunctionDefined("OPC_MATCHING_dpe_" + functions.keyAt(j)))
          callFunction("OPC_MATCHING_dpe_" + functions.keyAt(j), dp, dpType, functions.valueAt(j), res, mes);
        if (res < 0)
        {
          message += mes;
          return -5;
        }
//         DebugN(mes);
      }
    }
  }
  else
  {
    message += "отсутствует сопоставление DPE " + opcDPEPart + ", тип ТД: " + dpType + ", ТД: " + dp;
    dp = "";
//     dpType = "";
    return -3;
  }
  //TODO имя системы и проверить наличие ТД
  message += "ТД " + dp;
  return 0;
}

// Функция проверяет соотвествие адресов из выгрузки (Elesy или МЭК-104), передеваемых в параметрах
// @type - тип кадра @asdu @ioa @bit @dpe
//
public bool OPC_MATCHING_doesAddressMatch(int type, int asdu, int ioa, string bit, string dpe, string &message)
{
  if (!confOperations_doesConfExist(dpe, "address"))
  {
    message = dpe + ": отсутствует адрес";
    return false;
  }
  else if (confOperations_getConfValue(dpe, ":_address.._drv_ident") == "Elesy" || confOperations_getConfValue(dpe, ":_address.._drv_ident") == "IEC")
  {
    //GTAI_NPS_Elesy-240.0.1.0.64.27[1]
    string ref = confOperations_getConfValue(dpe, ":_address.._reference");
    ref.replace(":12", "");
    dyn_string temp = ref.split("-");
    ref = temp[2];
    string dpeBit = "";
    if (ref.contains("[") && ref.contains("]"))
    {
      dpeBit = substr(ref, ref.indexOf("[") + 1, ref.indexOf("]") - ref.indexOf("[") - 1);
      ref = strsplit(ref, "[")[1];
    }
    temp = ref.split(".");

    strreplace(temp[1], "C", "");
    // Для Elesy
    if (dpe.endsWith("_COT"))
    {
      strreplace(temp[1], "177", "187");
      strreplace(temp[1], "145", "155");
      strreplace(temp[1], "241", "251");
      strreplace(temp[1], "152", "156");
      strreplace(temp[1], "216", "212");
      strreplace(temp[1], "241", "251");
      dpeBit = "";
      bit = "";
    }

    int dpeType = (int)temp[1];
    int dpeASDU = 256 * (int)temp[2] + (int)temp[3];
    int dpeIOA = 256 * 256 * (int)temp[4] + 256 * (int)temp[5] + (int)temp[6];
//        DebugN(dpe, dpeType, dpeASDU, dpeIOA, dpeBit, type, asdu, ioa, bit);
//        delay(3);
    bool match = (type == dpeType && asdu == dpeASDU && ioa == dpeIOA && (int)bit == (int)dpeBit);
    message = match ? "адрес совпадает" : "адрес не совпадает";
    return match;
  }
  else
  {
    message = "адрес есть, неизвестный протокол";
    return false;
  }
}


public int OPC_MATCHING_getDPEByAddress(string baseDP, string dpType, int type, int asdu, int ioa, string bit, string &message, string &dpe)
{
//   DebugN("-------");
//    DebugN(baseDP, dpType);
//    DebugN(mDP_Filter);
//    delay(5);
  // Анализ времени
  time t0, t1;
  message = "";
  dpe = "";
  if (!dpExists(baseDP) || !patternMatch("*_*_*_*_*", baseDP))
  {
    message = "ТД не существует или не соответствует шаблону";
    return -1;
  }
  // С целью оптимизации храним массив потенциально возможных точек в массиве DPE, который является значением в маппинге @mDP_Filter для ключа @baseDP
  if (!mDP_Filter.contains(baseDP))
  {
    mDP_Filter.clear();
    string sysName = dpSubStr(baseDP, DPSUB_SYS);
    string sTemp = dpSubStr(baseDP, DPSUB_DP);
    dyn_string dsTemp = sTemp.split("_");

    // Формируем фильтра поиска адресов
    string filter = "";
    switch(dpType)
    {
      case "KP":
        filter = dsTemp [1] + "_{KP,LU}_" + dsTemp [3] + "_*";
        break;
      case "NPS":
        filter = dsTemp [1] + "{_??S_" + dsTemp[3] + "__,_KP_1_*_*,_SKSV_*__,_UVP_*__}";
        break;
      case "SIKN":
        filter = dsTemp[1] + "_{PSP,SIKN}_" + dsTemp[3] + "__";
        break;
      case "ZDV":
        if (dsTemp[5] == "")
        {
          message = "фильтр для поиска DPE слишком широкий";
          return -2;
        }
        filter = dsTemp[1] + "_" + dsTemp[2] + "_" + dsTemp[3] + "_" + dsTemp[4] + "_" + substr(dsTemp[5], 0, 1) + "*";
        break;
      case "NSS":
        filter = dsTemp[1] + "_" + dsTemp[2] + "_" + dsTemp[3] + "_" + dsTemp[4] + "_*";
        break;
      case "TEMK":
        filter = dsTemp[1] + "_" + dsTemp[2] + "_" + dsTemp[3] + "_" + dsTemp[4] + "_*";
        break;
      case "TKSI":
        filter = dsTemp[1] + "_" + dsTemp[2] + "_" + dsTemp[3] + "_" + dsTemp[4] + "_*";
        break;
      default:
        message = "фильтр для поиска DPE не определен в функции";
        return -2;
        break;
    }

  //   DebugN(filter);
  //   delay(1);

    string query = "SELECT '_distrib.._type' FROM '" + filter + "' REMOTE '" + sysName + "' WHERE '_distrib.._type' = 56";
    dyn_dyn_anytype result;
    dpQuery(query, result);
//     DebugN(result);
    t0 = getCurrentTime();
    mDP_Filter.insert(baseDP, result);
    t1 = getCurrentTime();
    DebugN("Время заполнения массива потенциальных DPE", second(t1 - t0), milliSecond(t1 - t0), baseDP);
//     delay(50);
/*
    // Заполняем массив адресов для одного соединения (род точки)
    dyn_string dsTempAddresses;
    t0 = getCurrentTime();

    for (int i = 2; i <= result.count(); i++)
    {
      string tempDPE = (string)result[i][1];
      if (confOperations_doesConfExist(tempDPE, "address") && (confOperations_getConfValue(tempDPE, ":_address.._drv_ident") == "Elesy" || confOperations_getConfValue(tempDPE, ":_address.._drv_ident") == "IEC"))
        dsTempAddresses.append(tempDPE);
    }
    mDP_Filter.insert(baseDP, dsTempAddresses);
    t1 = getCurrentTime();
    DebugN("Время заполнения массива потенциальных DPE", second(t1 - t0), milliSecond(t1 - t0), baseDP);*/
  }
  {
//     DebugN(mDP_Filter);
//     delay(10);
    dyn_dyn_anytype dsTempAddresses = mDP_Filter[baseDP];
    t0 = getCurrentTime();
    for (int i = 2; i <= dsTempAddresses.count(); i++)
    {
      dpe = (string)dsTempAddresses[i][1];
      if (OPC_MATCHING_doesAddressMatch(type, asdu, ioa, bit, dpe, message))
      {
        t1 = getCurrentTime();
        DebugN("Время поиска DPE", second(t1 - t0), milliSecond(t1 - t0), baseDP, "Найденная ТД: " + dpe);
        return 0;
      }
    }
    dpe = "";
    t1 = getCurrentTime();
    DebugN("Время поиска DPE", second(t1 - t0), milliSecond(t1 - t0), baseDP, "Найденная ТД: " + dpe);
    message = "не удалось найти DPE по адресу";
    return -2;
  }
}

//--------------------------------------------------------------------------------
//@private members
//--------------------------------------------------------------------------------

/* Параметры для функций DPE:
@dp - точка данных для изменения (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
@dpType - тип точки данных для изменения (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
@PARAM - параметр, указанный в json файле
@res - результат выполнения функции: <0 - ошибка, 0 - успешно (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
@message - сообщение о результате выполнения функции  (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
*/
private void OPC_MATCHING_dpe_replace(string &dp, string &dpType, mapping mReplace, int &res, string &message)
{
  message = "(" + dp + "): ";
  for (int i = 0; i < mReplace.count(); i++)
    dp.replace(mReplace.keyAt(i), mReplace.valueAt(i));
  message += "функция 'OPC_MATCHING_dpe_replace' новая ТД: " + dp;
  res = 0;
}

private void OPC_MATCHING_dpe_setDPT(string &dp, string &dpType, string newDPType, int &res, string &message)
{
  message = "(" + dp + "): ";
  dpType = newDPType;
  message += "функция 'OPC_MATCHING_dpe_setDPT' новый тип ТД: " + dpType;
  res = 0;
}

/* Параметры для функций сеттеров:
@opcTag - весь opc тег
@opcTagPart - текущая часть OPC-тега для обработки
@originalParentDP - оригинальный родительский объект, полученный по сопоставлениям изначально
@dp - точка данных для изменения (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
@PARAM - параметр, указанный в json файле
@res - результат выполнения функции: <0 - ошибка, 0 - успешно (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
@message - сообщение о результате выполнения функции  (ПЕРЕДАЕТСЯ ПО ССЫЛКЕ)
*/
private void OPC_MATCHING_dp_setDPName(string opcTag, string opcTagPart, string originalParentDP, string &dp, string &dpType, string dpName, int &res, string &message)
{
  message = "(" + opcTagPart + "): ";
  dyn_string dpParts = dp.split("_");
  if (dpParts.count() != 5)
  {
    message += "функция 'setDPName' ошибка: число '_' в ТД не равно 5! " + dp;
    res = -1;
  }
  else
  {
    dpParts[4] = dpName;
    dp = dpParts[1];
    for (int i = 2; i <= dpParts.count(); i++)
      dp += "_" + dpParts[i];
    message += "функция 'setDPName' новая ТД: " + dp;
    res = 0;
  }
}

private void OPC_MATCHING_dp_changeParent(string opcTag, string opcTagPart, string originalParentDP, string &dp, string &dpType, mapping mReplace, int &res, string &message)
{
  message = "(" + opcTagPart + "): ";
  for (int i = 0; i < mReplace.count(); i++)
    dp.replace(mReplace.keyAt(i), mReplace.valueAt(i));
  message += "функция 'changeParent' изменен род объект для ТД: " + dp;
  res = 0;
}

private void OPC_MATCHING_dp_saveOriginalParent(string opcTag, string opcTagPart, string originalParentDP, string &dp, string &dpType, anytype param, int &res, string &message)
{
  message = "(" + opcTagPart + "): ";
  dyn_string dpParts = dp.split("_");
  dyn_string parentDPParts = originalParentDP.split("_");
  if (dpParts.count() != 5)
  {
    message += "функция 'saveOriginalParent' ошибка: число '_' в ТД не равно 5! " + dp;
    res = -1;
  }
  else if (parentDPParts.count() != 5)
  {
    message += "функция 'saveOriginalParent' ошибка: число '_' в ТД не равно 5! " + originalParentDP;
    res = -1;
  }
  else
  {
    dp  = parentDPParts[1] + "_" + parentDPParts[2] + "_" + parentDPParts[3] + "_" + dpParts[4] + "_" + dpParts[5];
    message += "функция 'saveOriginalParent' изменен род объект для ТД: " + dp;
    res = 0;
  }
}


private void OPC_MATCHING_dp_setObjectNumber(string opcTag, string opcTagPart, string originalParentDP, string &dp, string &dpType, anytype param, int &res, string &message)
{
  message = "(" + opcTagPart + "): ";
  dyn_string dpParts = dp.split("_");
  if (dpParts.count() != 5)
  {
    message += "функция 'setObjectNumber' ошибка: число '_' в ТД не равно 5! " + dp;
    res = -1;
  }
  else
  {
    dyn_string opcTagPartParts = opcTagPart.split("_");
    if (opcTagPartParts.count() < 2)
      dpParts[5] = "1";
    else
    {
      string number = opcTagPartParts[2];
      for (int i = 3; i <= opcTagPartParts.count(); i++)
        number += "-" + opcTagPartParts[i];
      dpParts[5] = number;
    }
    dp = dpParts[1];
    for (int i = 2; i <= dpParts.count(); i++)
      dp += "_" + dpParts[i];
    message += "функция 'setObjectNumber' новая ТД: " + dp;
    res = 0;
  }
}

private void OPC_MATCHING_dp_setDPT(string opcTag, string opcTagPart, string originalParentDP, string &dp, string &dpType, mapping mDPT, int &res, string &message)
{
  message = "(" + opcTagPart + "): ";
  for (int i = 0; i < mDPT.count(); i++)
  {
    if (patternMatch(mDPT.keyAt(i), dp))
      dpType = mDPT.valueAt(i);
  }
  message += "функция 'setDPT' новый тип ТД: " + dpType;
  res = 0;
}


// Добавление подключения МЭК-4 "на лету"
private int addElesyConn(string connName, int drvNum, string &message)
{
  connName.replace("-", "");
  dyn_string dpTypes = dpTypes("_ElesyDrv");
  if (dpTypes.count() == 0)
  {
    message = "Не существует типа ТД _ElesyDrv!";
    return -1;
  }

  if (!dpExists("_ElesyDrv" + drvNum))
  {
    updateFirstFreeId(dpId);
    if (dpCreate("_ElesyDrv" + drvNum, "_ElesyDrv", getSystemId(), dpId) < 0)
    {
      DebugN("Ошибка при создании ТД драйвера Elesy МЭК-4 " + drvDP + "!");
      return -2;
    }
  }

  if (!dpExists("_ElesyDrv" + drvNum + "_2"))
  {
    updateFirstFreeId(dpId);
    if (dpCreate("_ElesyDrv" + drvNum + "_2", "_ElesyDrv", getSystemId(), dpId) < 0)
    {
      DebugN("Ошибка при создании ТД драйвера Elesy МЭК-4 " + drvDP + "!");
      return -2;
    }
  }

  dyn_string drvConnections;
  dpGet("_ElesyDrv" + drvNum + ".Config", drvConnections);
  for (int i = 1; i <= drvConnections.count(); i++)
  {
    string conn = drvConnections[i];
    if (conn.contains(connName))
      break;
    if (i == drvConnections.count())
    {
      drvConnections.append(connName + "-127.0.0.1:2404 -1 0 0");
      if (dpSet("_ElesyDrv" + drvNum + ".Config", drvConnections) < 0)
      {
        DebugN("Ошибка при добавления подключения " + connName + "!");
        return -3;
      }
    }
  }
  if (drvConnections.count() == 0)
  {
    drvConnections.append(connName + "-127.0.0.1:2404 -1 0 0");
    if (dpSet("_ElesyDrv" + drvNum + ".Config", drvConnections) < 0)
    {
      DebugN("Ошибка при добавления подключения " + connName + "!");
      return -3;
    }
  }


  dpGet("_ElesyDrv" + drvNum + "_2.Config", drvConnections);
  for (int i = 1; i <= drvConnections.count(); i++)
  {
    string conn = drvConnections[i];
    if (conn.contains(connName))
      break;
    if (i == drvConnections.count())
    {
      drvConnections.append(connName + "-127.0.0.1:2404 -1 3600 3600");
      if (dpSet("_ElesyDrv" + drvNum + "_2.Config", drvConnections) < 0)
      {
        DebugN("Ошибка при добавления подключения " + connName + "!");
        return -3;
      }
    }
  }
  if (drvConnections.count() == 0)
  {
    drvConnections.append(connName + "-127.0.0.1:2404 -1 3600 3600");
    if (dpSet("_ElesyDrv" + drvNum + "_2.Config", drvConnections) < 0)
    {
      DebugN("Ошибка при добавления подключения " + connName + "!");
      return -3;
    }
  }
  message = "Успешно добавлено соединение " + connName + " на драйвер " + drvNum;
  return 0;
}




// 0 - успешно, <0 - код ошибки, >0 - количество ошибок при заливке
private int uploadOneFile(string fileName, string &message)
{
//   dyn_string lines = readFileANSI(_PROJ_PATH + SOURCE_REL_PATH + "/Upload/Address/" + fileName, true);
  dyn_string lines = readFileANSI(fileName, true);

  // Проверка файла на правильный тип протокола
  message = fileName + ": неправильный тип кадра";
  if (lines.count() == 0)
    return -1;
  else
  {
    string s = lines[1];
    dyn_string ds = s.split(";");
    if (ds.count() < 2)
      return -1;
    else
      s = ds[2];
    if (s != "МЭК-4")
      return -1;
  }

  int errorCounter = 0;
  int dpeCounter = lines.count();
  for (int i = 1; i <= lines.count(); i++)
  {
    if (lines[i] == "")
      continue;
    PROGRESS_BAR.value(i / (float)dpeCounter * 100);
    dyn_string info = strsplit(lines[i], ";");
    if (info.count() < 7)
    {
      Log((i + 1) + " строка: меньше 7 столбцов, пропуск");
      errorCounter++;
    }
    else
    {
      string dpe     = info[1];
      if (!dpExists(dpe))
      {
        errorCounter++;
        Log((i + 1) + " строка: " +  dpe + " не существует!");
        continue;
      }
      string drvType = info[2];
      string type    = (int)info[3];
      string ioa     = info[4];
      // КОСТЫЛЬ
      if (ioa.endsWith("h"))
      {
        if (ioa == "0h")
          ioa = "0";
        else
        {
          ioa.remove(ioa.length() - 1, 1);
          ioa = conv(ioa, 16, 10);
          if (ioa == "")
          {
            Log((i + 1) + " строка: ошибка в IOA");
            errorCounter++;
            continue;
          }
        }
      }

      string conn    = info[5];
      conn.replace("-", "_");
      string asdu    = (int)info[6];
      string drvNum  = info[7];
      //Временное решение распределения по драйверам
//       srand();
//       drvNum = rand() % 10 + 1;
      //////

      string bit     = (info.count() >= 8)  ? (info[8] == "") ? 0 : (int)info[8] : -1;
      string desc    = (info.count() >= 9) ? info[9] : "";

      if (desc != "")
      {
        langString lsDesc;
        setLangString(lsDesc, 0, desc);
        setLangString(lsDesc, 1, "");
        if (dpSetDescription(dpe, lsDesc) == 0)
          Log((i + 1) + " строка: Успешно изменено описание для ТД " + dpe);
        else
        {
          errorCounter++;
          Log((i + 1) + " строка: Ошибка при изменении описания для ТД " + dpe);
        }
      }

      string needCOT = cbCOT.state(0);
      bool activeAddr = cbTuOff.state(0) && (patternMatch("*.TR.*", dpe) || patternMatch("*.TU.*", dpe));
      int err = 0;
      string message;
      if (drvType == "МЭК-4")
      {
        if (cb_setParrentSettings.state(0) || cb_setParrentSettings.state(1))
        {
          if (dpExists("_PNR_TNV.dp_elesyConn"))
          {
            string json;
            dpGet("_PNR_TNV.dp_elesyConn", json);
            mapping m = jsonDecode(json);
            if (!m.contains(getParentObject(dpe)))
            {
              Log("Не найден родительский объект для ТД " + dpe);
              continue;
            }
            string parentDP = getParentObject(dpe);
            if (cb_setParrentSettings.state(0) && m[parentDP].contains("connName"))
              conn = m[parentDP]["connName"];
            if (cb_setParrentSettings.state(1) && m[parentDP].contains("drvNum"))
              drvNum = (int)m[parentDP]["drvNum"];
          }
          else
          {
            Log("Не найдена ТД _PNR_TNV.dp_elesyConn, ТД " + dpe);
            continue;
          }
        }

        else
        {
          err = addElesyConn(conn, drvNum, message);
          if (err < 0)
          {
            errorCounter++;
            DebugN(message);
            continue;
          }
        }

        if ((patternMatch("*.TU.*", dpe) || patternMatch("*.TR.*", dpe)) && needCOT && dpExists(dpe + "_COT"))
        {
          err = addElesyAddr(dpe + "_COT", ioa, type, drvNum, conn, asdu, bit, true, !activeAddr, message);
          dpSet(dpe + "_COT:_original.._active", true);
          if (err < 0)
          {
            errorCounter++;
            Log(message + ": " + dpe + "_COT");
          }
        }
        else if (patternMatch("*.TU.*", dpe) && needCOT && !dpExists(dpe + "_COT"))
        {
          errorCounter++;
          dpeCounter++;
          Log("ТД " + dpe + "_COT не существует");
        }

        /*if (patternMatch("*.TR.*", dpe) && needCOT && dpExists(dpe + "_COT"))
        {
          err = addElesyAddr(dpe + "_COT", ioa, type, drvNum, conn, asdu, bit, true, !activeAddr, message);
          dpSet(dpe + "_COT:_original.._active", true);
          if (err < 0)
            Log(message + ": " + dpe + "_COT");
        }
        else if (patternMatch("*.TR.*", dpe) && needCOT && !dpExists(dpe + "_COT"))
          Log("ТД " + dpe + "_COT не существует");*/

        int err = addElesyAddr(dpe, ioa, type, drvNum, conn, asdu, bit, false, !activeAddr, message);
        if (err < 0)
        {
          errorCounter++;
          Log(message + ": " + dpe);
        }
//         DebugN(dpe, ioa, type, drvNum, conn, asdu, bit, false, !activeAddr, message, err);
      }
      else
      {
        errorCounter++;
        Log("В строке " + (i + 1) + "неизвестный тип драйвера, пропуск");
      }
    }
  }
  if (errorCounter == dpeCounter)
  {
    message = fileName + ": нет ТД в данном проекте";
    return -2;
  }
  message = fileName + ": количество ошибок: " + errorCounter;
  return errorCounter;
}

private int addElesyAddr(string dpe, int ioa, int type, int drvNum, string conn, int asdu, int bit, bool needCOT, bool activeAddr, string &message)
{
  mapping m_type_datatype = makeMapping(148, 1002,
                                        180, 1002,
                                        212, 1002,
                                        244, 1002,
                                        152, 1002,
                                        184, 1002,
                                        216, 1002,
                                        248, 1002,
                                        144, 1003,
                                        176, 1003,
                                        208, 1003,
                                        240, 1003,
                                        145, 1003,
                                        177, 1003,
                                        209, 1003,
                                        241, 1003,
                                        144, 1003,

                                        "*", 1001);

  mapping m_type_oldNewCompare = makeMapping(145, false,
                                             177, false,
                                             209, false,
                                             241, false,
                                             150, false,
                                             182, false,
                                             214, false,
                                             246, false,
                                             151, false,
                                             183, false,
                                             215, false,
                                             247, false,
                                             152, false,
                                             184, false,
                                             216, false,
                                             248, false,
                                             "*", true);

  mapping m_type_direction = makeMapping(144, 2,
                                         176, 2,
                                         208, 2,
                                         240, 2,
                                         145, 1,
                                         177, 1,
                                         209, 1,
                                         241, 1,
                                         146, 2,
                                         178, 2,
                                         210, 2,
                                         242, 2,
                                         147, 2,
                                         179, 2,
                                         217, 2,
                                         243, 2,
                                         148, 2,
                                         180, 2,
                                         212, 2,
                                         244, 2,
                                         149, 2,
                                         181, 2,
                                         213, 2,
                                         245, 2,
                                         150, 1,
                                         182, 1,
                                         214, 1,
                                         246, 1,
                                         151, 1,
                                         183, 1,
                                         215, 1,
                                         247, 1,
                                         152, 1,
                                         184, 1,
                                         216, 1,
                                         248, 1);

  mapping m_type_needBit  =  makeMapping(144, true,
                                         176, true,
                                         208, true,
                                         240, true,
                                         145, true,
                                         177, true,
                                         209, true,
                                         241, true,
                                         146, false,
                                         178, false,
                                         210, false,
                                         242, false,
                                         147, false,
                                         179, false,
                                         217, false,
                                         243, false,
                                         148, false,
                                         180, false,
                                         212, false,
                                         244, false,
                                         149, false,
                                         181, false,
                                         213, false,
                                         245, false,
                                         150, false,
                                         182, false,
                                         214, false,
                                         246, false,
                                         151, false,
                                         183, false,
                                         215, false,
                                         247, false,
                                         152, false,
                                         184, false,
                                         216, false,
                                         248, false);


// DebugN(dpe, conn, asdu, ioa, type, bit, needCOT, m_type_direction, m_type_needBit);
  string reference = getConnectionStringElesy(conn, asdu, ioa, type, bit, needCOT, m_type_direction, m_type_needBit, message);
  if (reference == "")
    return -1;
//   DebugN(m_type_oldNewCompare, dpe);
  if (dpExists(dpe))
  {
    if (dpSetTimed(0, dpe + ":_distrib.._type", DPCONFIG_DISTRIBUTION_INFO, dpe + ":_distrib.._driver", drvNum) < 0)
    {
      message = "Ошибка при добавлении distrib";
      return -1;
    }

    if (dpSetTimed(0, dpe + ":_address.._type", DPCONFIG_PERIPH_ADDR_MAIN,
          dpe + ":_address.._drv_ident", "Elesy",
          dpe + ":_address.._datatype", m_type_datatype.contains(type) ? m_type_datatype[type] : 1001,
          dpe + ":_address.._reference", reference,
          dpe + ":_address.._direction", needCOT ? 2 : m_type_direction[type],
          dpe + ":_address.._active", activeAddr,
          dpe + ":_address.._lowlevel", m_type_oldNewCompare.contains(type) ? m_type_oldNewCompare[type] : m_type_oldNewCompare["*"]) < 0)
    {
      message = "Ошибка при добавлении distrib";
      return -1;
    }

    if (dpSetTimed(0, dpe + ":_original.._active", true) < 0)
    {
      message = "Ошибка при добавлении _original.._active";
      return -1;
    }

    message = "Успешно добавлен адрес";
    return 0;
  }
  else
  {
    message = dpe + " не существует!";
    return -1;
  }
}


private string getConnectionStringElesy(string connection, int asdu, int ioa, int type, int bit, bool needCOT, mapping m_type_direction, mapping m_type_needBit, string &message)
{
  if (asdu < 1 || asdu > 65535)
  {
    message = "Задан некорректный ASDU!";
    return "";
  }
  else if (connection == "")
  {
    message = "Задано пустое имя соединения!";
    return "";
  }
  else if (!m_type_direction.contains(type) || !m_type_needBit.contains(type))
  {
    message = "Задан некорректный тип кадра!";
    return "";
  }
  else if (bit < -1 || bit > 7)
  {
    message = "Задан некорректный номер бита!";
    return "";
  }
  else if (ioa < 0 || asdu > 16777215)
  {
    message = "Задан некорректный IOA!";
    return "";
  }

  int ioa1 = (int)(ioa / (256 * 256));
  int _ioa1 = ioa % (256 * 256);
  int ioa2 = (int)(_ioa1 / 256);
  int ioa3 = _ioa1 % 256;

  int asdu1 = (int)(asdu / 256);
  int asdu2 = asdu % 256;

  message = "Reference-строка сформирована успешно!";

  string _bit = m_type_needBit[type] ? ("[" + bit + "]") : "";
  string _cot = needCOT ? "_COT" : "";
  string _dir = (!needCOT && m_type_direction[type] == 1) ? ":0" : "";

//   DebugN(connection, type, asdu1, asdu2, ioa1, ioa2, ioa3, _bit, _cot, m_type_needBit[type]);

  return connection + "-" + (string)type + "." + (string)asdu1 + "." + (string)asdu2 + "." + (string)ioa1 + "." + (string)ioa2 + "." + (string)ioa3 + _bit + _cot + _dir;
}

// Перевод из одной системы счисления в другую
private char ntoa(int n) // преобразование номера цифры в символ
{
    if ((n >= 0) && (n <= 9))
        return '0' + n;
    else
        return 'A' - 10 + n;

}

private int aton(char a) // преобразование символа в номер цифры
{
    if ((a >= '0') && (a <= '9'))
        return a - '0';
    else if ((a >= 'a') && (a <= 'z'))
        return a - 'a' + 10;
    else
        return a - 'A' + 10;
}

// Преобразование из одной системы счисления в другую
// s - число в системе счисления по основанию fs
// функция возвращает число в системе счисления fd
private string conv(string s, int fs, int fd)
{
    int A = 0;
    for (int i = 0; i < s.length(); i++)
    {
        char a;
        a = aton(s[i]);
        if ((a >= 0) && (a <= fs))
            A = A * fs + a;
        else
            return "";
        // число в неверном формате
    }
    string sd = "";
    while (A!= 0)
    {
        sd = ntoa(A % fd) + sd;
        A /= fd;
    }
    return sd;
}


