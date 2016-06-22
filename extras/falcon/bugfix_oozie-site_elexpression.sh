#!/usr/bin/env bash

## Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh
ambari_configs

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-job-submit-instances \
    "
      now=org.apache.oozie.extensions.OozieELExtensions#ph1_now_echo,
      today=org.apache.oozie.extensions.OozieELExtensions#ph1_today_echo,
      yesterday=org.apache.oozie.extensions.OozieELExtensions#ph1_yesterday_echo,
      currentWeek=org.apache.oozie.extensions.OozieELExtensions#ph1_currentWeek_echo,
      lastWeek=org.apache.oozie.extensions.OozieELExtensions#ph1_lastWeek_echo,
      currentMonth=org.apache.oozie.extensions.OozieELExtensions#ph1_currentMonth_echo,
      lastMonth=org.apache.oozie.extensions.OozieELExtensions#ph1_lastMonth_echo,
      currentYear=org.apache.oozie.extensions.OozieELExtensions#ph1_currentYear_echo,
      lastYear=org.apache.oozie.extensions.OozieELExtensions#ph1_lastYear_echo,
      formatTime=org.apache.oozie.coord.CoordELFunctions#ph1_coord_formatTime_echo,
      latest=org.apache.oozie.coord.CoordELFunctions#ph2_coord_latest_echo,
      future=org.apache.oozie.coord.CoordELFunctions#ph2_coord_future_echo
     "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-action-create-inst \
    "
      now=org.apache.oozie.extensions.OozieELExtensions#ph2_now_inst,
      today=org.apache.oozie.extensions.OozieELExtensions#ph2_today_inst,
      yesterday=org.apache.oozie.extensions.OozieELExtensions#ph2_yesterday_inst,
      currentWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_currentWeek_inst,
      lastWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_lastWeek_inst,
      currentMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_currentMonth_inst,
      lastMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_lastMonth_inst,
      currentYear=org.apache.oozie.extensions.OozieELExtensions#ph2_currentYear_inst,
      lastYear=org.apache.oozie.extensions.OozieELExtensions#ph2_lastYear_inst,
      latest=org.apache.oozie.coord.CoordELFunctions#ph2_coord_latest_echo,
      future=org.apache.oozie.coord.CoordELFunctions#ph2_coord_future_echo,
      formatTime=org.apache.oozie.coord.CoordELFunctions#ph2_coord_formatTime,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-action-create \
    "
      now=org.apache.oozie.extensions.OozieELExtensions#ph2_now,
      today=org.apache.oozie.extensions.OozieELExtensions#ph2_today,
      yesterday=org.apache.oozie.extensions.OozieELExtensions#ph2_yesterday,
      currentWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_currentWeek,
      lastWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_lastWeek,
      currentMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_currentMonth,
      lastMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_lastMonth,
      currentYear=org.apache.oozie.extensions.OozieELExtensions#ph2_currentYear,
      lastYear=org.apache.oozie.extensions.OozieELExtensions#ph2_lastYear,
      latest=org.apache.oozie.coord.CoordELFunctions#ph2_coord_latest_echo,
      future=org.apache.oozie.coord.CoordELFunctions#ph2_coord_future_echo,
      formatTime=org.apache.oozie.coord.CoordELFunctions#ph2_coord_formatTime,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-job-submit-data \
    "
      now=org.apache.oozie.extensions.OozieELExtensions#ph1_now_echo,
      today=org.apache.oozie.extensions.OozieELExtensions#ph1_today_echo,
      yesterday=org.apache.oozie.extensions.OozieELExtensions#ph1_yesterday_echo,
      currentWeek=org.apache.oozie.extensions.OozieELExtensions#ph1_currentWeek_echo,
      lastWeek=org.apache.oozie.extensions.OozieELExtensions#ph1_lastWeek_echo,
      currentMonth=org.apache.oozie.extensions.OozieELExtensions#ph1_currentMonth_echo,
      lastMonth=org.apache.oozie.extensions.OozieELExtensions#ph1_lastMonth_echo,
      currentYear=org.apache.oozie.extensions.OozieELExtensions#ph1_currentYear_echo,
      lastYear=org.apache.oozie.extensions.OozieELExtensions#ph1_lastYear_echo,
      dataIn=org.apache.oozie.extensions.OozieELExtensions#ph1_dataIn_echo,
      instanceTime=org.apache.oozie.coord.CoordELFunctions#ph1_coord_nominalTime_echo_wrap,
      formatTime=org.apache.oozie.coord.CoordELFunctions#ph1_coord_formatTime_echo,
      dateOffset=org.apache.oozie.coord.CoordELFunctions#ph1_coord_dateOffset_echo,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-action-start \
    "
      now=org.apache.oozie.extensions.OozieELExtensions#ph2_now,
      today=org.apache.oozie.extensions.OozieELExtensions#ph2_today,
      yesterday=org.apache.oozie.extensions.OozieELExtensions#ph2_yesterday,
      currentWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_currentWeek,
      lastWeek=org.apache.oozie.extensions.OozieELExtensions#ph2_lastWeek,
      currentMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_currentMonth,
      lastMonth=org.apache.oozie.extensions.OozieELExtensions#ph2_lastMonth,
      currentYear=org.apache.oozie.extensions.OozieELExtensions#ph2_currentYear,
      lastYear=org.apache.oozie.extensions.OozieELExtensions#ph2_lastYear,
      latest=org.apache.oozie.coord.CoordELFunctions#ph3_coord_latest,
      future=org.apache.oozie.coord.CoordELFunctions#ph3_coord_future,
      dataIn=org.apache.oozie.extensions.OozieELExtensions#ph3_dataIn,
      instanceTime=org.apache.oozie.coord.CoordELFunctions#ph3_coord_nominalTime,
      dateOffset=org.apache.oozie.coord.CoordELFunctions#ph3_coord_dateOffset,
      formatTime=org.apache.oozie.coord.CoordELFunctions#ph3_coord_formatTime,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-sla-submit \
    "
      instanceTime=org.apache.oozie.coord.CoordELFunctions#ph1_coord_nominalTime_echo_fixed,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.ELService.ext.functions.coord-sla-create \
    "
      instanceTime=org.apache.oozie.coord.CoordELFunctions#ph2_coord_nominalTime,
      user=org.apache.oozie.coord.CoordELFunctions#coord_user
    "

${ambari_config_set} oozie-site \
    oozie.service.HadoopAccessorService.supported.filesystems \
    "*"
