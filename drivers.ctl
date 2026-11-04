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


//--------------------------------------------------------------------------------
// Variables and Constants

private const int MIN_COMMON_COLUMNS_COUNT = 8;
private const int MIN_IEC_COLUMNS_COUNT = 15;
private const mapping DRV_TYPE_MATCHES = makeMapping("МЭК-104", makeMapping("drvIdent", "IEC", "functions", makeDynString("getReference", "getDirection", "getDataType")));
//                                              "МЭК-4",   "Elesy");

private const mapping IEC_104_TYPES = makeMapping(30, makeMapping("dataType", 521, "cmd", false, "direction", DPATTR_ADDR_MODE_INPUT_SPONT),
                                                  36, makeMapping("dataType", 526, "cmd", false, "direction", DPATTR_ADDR_MODE_INPUT_SPONT),
                                                  35, makeMapping("dataType", 525, "cmd", false, "direction", DPATTR_ADDR_MODE_INPUT_SPONT),
                                                  45, makeMapping("dataType", 532, "cmd", true,  "direction", DPATTR_ADDR_MODE_OUTPUT_SINGLE),
                                                  50, makeMapping("dataType", 526, "cmd", true,  "direction", DPATTR_ADDR_MODE_OUTPUT_SINGLE),
                                                  33, makeMapping("dataType", 531, "cmd", false, "direction", DPATTR_ADDR_MODE_INPUT_SPONT)
                                                  );
private const int IEC_104_COT_DATATYPE = 544;
private const int IEC_104_COT_DIRECTION = DPATTR_ADDR_MODE_INPUT_SPONT;

// Нумерация столбцов
private const int DPE_COLUMN_NUMBER = 1;
private const int SYS_COLUMN_NUMBER = 2;
private const int DRV_TYPE_COLUMN_NUMBER = 3;
private const int DRV_NUM_COLUMN_NUMBER = 4;
private const int SUBINDEX_COLUMN_NUMBER = 5;
private const int OFFSET_COLUMN_NUMBER = 6;
private const int POLL_GROUP_COLUMN_NUMBER = 7;
private const int LOW_LEVEL_COMP_COLUMN_NUMBER = 8;
private const int DESC_COLUMN_NUMBER = 9;

private const int IEC_CONNECTION_COLUMN_NUMBER = 10;
private const int IEC_ASDU_COLUMN_NUMBER = 11;
private const int IEC_TYPE_COLUMN_NUMBER = 12;
private const int IEC_IOA_COLUMN_NUMBER = 13;
private const int IEC_IS_COT_COLUMN_NUMBER = 14;
private const int IEC_QOC_COLUMN_NUMBER = 15;

//--------------------------------------------------------------------------------

int drivers_setAddressToDPE(dyn_string info, string &message)
{
  DebugFN("test", (string)info);
  message.clear();
  string dpe, drvType, pollGroup, reference;
  int drvNum, direction, dataType;
  uint subindex, offset;
  bool lowLevel;
  int res = getCommonAddressInfo(info, dpe, drvType, drvNum, subindex, offset, pollGroup, lowLevel, message);

  DebugFN("test", res, message);
  DebugFN("test", dpe, drvType, drvNum, subindex, offset, pollGroup, lowLevel);

  if (res >= 0)
  {
    for (int i = 1;  i <= DRV_TYPE_MATCHES[drvType]["functions"].count(); i++)
    {
      string functionPattern = DRV_TYPE_MATCHES[drvType]["functions"][i];
      switch (functionPattern)
      {
        case "getReference":
          res = callFunction(functionPattern + DRV_TYPE_MATCHES[drvType]["drvIdent"], info, reference, message);
          DebugFN("test", res, message, reference);
          if (res < 0) return res;
          break;
        case "getDirection":
          res = callFunction(functionPattern + DRV_TYPE_MATCHES[drvType]["drvIdent"], info, direction, message);
          DebugFN("test", res, message, direction);
          if (res < 0) return res;
          break;
        case "getDataType":
          res = callFunction(functionPattern + DRV_TYPE_MATCHES[drvType]["drvIdent"], info, dataType, message);
          DebugFN("test", res, message, dataType);
          if (res < 0) return res;
          break;
        default:
          DebugFN("test", functionPattern, "не найдена функция");
          break;
      }
    }
    string desc = info[DESC_COLUMN_NUMBER];
    if (!desc.isEmpty())
    {
      res = confOperations_dpSetDescription(dpe, desc, true, message);
      DebugFN("test", desc, res, message);
      if (res < 0) return res;
    }
    res += dpSet(dpe + ":_distrib.._type", DPCONFIG_DISTRIBUTION_INFO,
                dpe + ":_distrib.._driver", drvNum,
                dpe + ":_address.._type", DPCONFIG_PERIPH_ADDR_MAIN,
                dpe + ":_address.._drv_ident", DRV_TYPE_MATCHES[drvType]["drvIdent"],
                dpe + ":_address.._reference", reference,
                dpe + ":_address.._subindex", subindex,
                dpe + ":_address.._offset", offset,
                dpe + ":_address.._direction", direction,
                dpe + ":_address.._datatype", dataType,
                dpe + ":_address.._poll_group", pollGroup,
                dpe + ":_address.._lowlevel", lowLevel,
                dpe + ":_address.._active", true
                );
      DebugFN("dpSet", dpe + ":_address.._type", DPCONFIG_PERIPH_ADDR_MAIN + "\n",
                       dpe + ":_address.._drv_ident", DRV_TYPE_MATCHES[drvType]["drvIdent"] + "\n",
                       dpe + ":_address.._reference", reference + "\n",
                       dpe + ":_address.._subindex", subindex + "\n",
                       dpe + ":_address.._offset", offset + "\n",
                       dpe + ":_address.._direction", direction + "\n",
                       dpe + ":_address.._datatype", dataType + "\n",
                       dpe + ":_address.._poll_group", pollGroup + "\n",
                       dpe + ":_address.._lowlevel", lowLevel + "\n",
                       dpe + ":_address.._active", true + "\n",
                       dpe + ":_distrib.._type", DPCONFIG_DISTRIBUTION_INFO + "\n",
                       dpe + ":_distrib.._driver", drvNum
                       );
      message = dpe + ": " + (res == 0 ? "успешно добавлен адрес" : "ошибка при добавлении адреса");
  }
  return res;
}


private int getReferenceIEC(dyn_string info, string &reference, string &message)
{
  message = "Формирование reference-строки МЭК-104: ";
  int res = 0;
  if (info.count() < MIN_IEC_COLUMNS_COUNT)
  {
    message += " в строке меньше " + MIN_IEC_COLUMNS_COUNT + " строк";
    res = -1;
  }
  else
  {
    string connection = info[IEC_CONNECTION_COLUMN_NUMBER];
    int asdu = info[IEC_ASDU_COLUMN_NUMBER];
    int type = info[IEC_TYPE_COLUMN_NUMBER];
    int ioa = info[IEC_IOA_COLUMN_NUMBER];
    bool cot = info[IEC_IS_COT_COLUMN_NUMBER];
    int qoc = info[IEC_QOC_COLUMN_NUMBER];
    if (asdu < 1 || asdu > 65535)
    {
      message += "задан некорректный ASDU!";
      res = -2;
    }
    else if (!IEC_104_TYPES.contains(type))
    {
      message += "задан некорректный тип кадра!";
      res = -3;
    }
    else if (ioa < 0 || asdu > 16777215)
    {
      message += "задан некорректный IOA!";
      res = -4;
    }
    else if (qoc < 0 || qoc > 127)
    {
      message += "заданы некорректные биты команды!";
      res = -5;
    }
    else
    {
      int ioa1 = (int)(ioa / (256 * 256));
      int _ioa1 = ioa % (256 * 256);
      int ioa2 = (int)(_ioa1 / 256);
      int ioa3 = _ioa1 % 256;

      int asdu1 = (int)(asdu / 256);
      int asdu2 = asdu % 256;

      string _qoc = !cot && IEC_104_TYPES[type]["cmd"] && qoc != 0 ? ":" + qoc : "";
      reference = connection + "-" + (cot ? "C" : "") + type + _qoc + "." + asdu1 + "." + asdu2 + "." + ioa1 + "." + ioa2 + "." + ioa3;
      message += reference;
      res = 0;
    }
  }
  return res;
}

private int getDirectionIEC(dyn_string info, int &direction, string &message)
{
  message = "Направление сигнала МЭК-104: ";
  int type = info[IEC_TYPE_COLUMN_NUMBER];
  bool cot = info[IEC_IS_COT_COLUMN_NUMBER];
  if (cot && IEC_104_TYPES[type]["cmd"])
  {
    direction = IEC_104_COT_DIRECTION;
    message += IEC_104_COT_DIRECTION + " (COT)";
  }
  else
  {
    direction = IEC_104_TYPES[type]["direction"];
    message += direction;
  }
  return 0;
}

private int getDataTypeIEC(dyn_string info, int &dataType, string &message)
{
  message = "Тип преобразования сигнала МЭК-104: ";
  int type = info[IEC_TYPE_COLUMN_NUMBER];
  bool cot = info[IEC_IS_COT_COLUMN_NUMBER];
  if (cot && IEC_104_TYPES[type]["cmd"])
  {
    dataType = IEC_104_COT_DATATYPE;
    message += IEC_104_COT_DATATYPE + " (COT)";
  }
  else
  {
    dataType = IEC_104_TYPES[type]["dataType"];
    message += dataType;
  }
  return 0;
}



private int getCommonAddressInfo(dyn_string info, string &dpe, string &drvType, int &drvNum, uint &subindex, uint &offset, string &pollGroup, bool &lowLevelComp, string &message)
{
  message = "Считывание общих для всех драйверов полей: ";
  int res = 0;
  if (info.count() < MIN_COMMON_COLUMNS_COUNT)
  {
    message += "в строке меньше " + MIN_COLUMNS_COUNT + " строк";
    res = -1;
  }
  else
  {
    dpe = info[DPE_COLUMN_NUMBER];
    string sysName = info[SYS_COLUMN_NUMBER] == "" ? getSystemName() : info[SYS_COLUMN_NUMBER];
    if (!dpe.contains(":")) dpe = sysName + ":" + dpe;

    if (!confOperations_dpExists(dpe))
    {
      message += "ТД " + dpe + " не существует";
      res = -2;
    }
    else if (!DRV_TYPE_MATCHES.contains(info[DRV_TYPE_COLUMN_NUMBER]))
    {
      message += "неизвестный тип драйвера";
      res = -3;
    }
    else
    {
      drvType = info[DRV_TYPE_COLUMN_NUMBER];
      drvNum = info[DRV_NUM_COLUMN_NUMBER];
      if (drvNum == 0)
      {
        message += "некорректный номер драйвера";
        res = -4;
      }
      else
      {
        subindex = (uint)info[SUBINDEX_COLUMN_NUMBER];
        offset = (uint)info[OFFSET_COLUMN_NUMBER];
        lowLevelComp = info[LOW_LEVEL_COMP_COLUMN_NUMBER];
        if (info[POLL_GROUP_COLUMN_NUMBER] != "")
        {
          pollGroup = sysName +  ":_"  + info[POLL_GROUP_COLUMN_NUMBER];
          if (!confOperations_dpExists(pollGroup))
          {
            message += "ТД группы опроса " + pollGroup + " не существует";
            res = -5;
          }
          else
          {
            message += "успешно";
            res = 0;
          }
        }
        else
        {
          message += "успешно";
          res = 0;
        }
      }
    }
  }
  return res;
}




































