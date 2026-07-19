/// Tab / 策略来源元数据（与 Relay /v1/status.tab_meta 对齐；本地兜底）
const tabOrder = ['follow0', 'follow1', 'followxq'];

const tabTitles = {
  'follow0': '6122双线程1',
  'follow1': '6122双线程2',
  'followxq': '6122更新——X专用',
};

/// follow0 / followxq：含 DSS持仓3、XXcomet；follow1 不含果仁
const sourcesFollow0 = [
  {'index': 0, 'label': 'XX'},
  {'index': 1, 'label': 'DD'},
  {'index': 2, 'label': '聚宽'},
  {'index': 3, 'label': 'DS'},
  {'index': 4, 'label': 'DSS'},
  {'index': 5, 'label': 'DSS持仓3'},
  {'index': 6, 'label': 'XXcomet'},
];

const sourcesFollow1 = [
  {'index': 0, 'label': 'XX'},
  {'index': 1, 'label': 'DD'},
  {'index': 2, 'label': '聚宽'},
  {'index': 3, 'label': 'DS'},
  {'index': 4, 'label': 'DSS'},
];

List<Map<String, dynamic>> sourcesFor(String tabId) =>
    tabId == 'follow1' ? List<Map<String, dynamic>>.from(sourcesFollow1) : List<Map<String, dynamic>>.from(sourcesFollow0);

/// 全量配置字段（与桌面 _get_config 对齐），用于表单编辑
const configFieldGroups = <String, List<Map<String, String>>>{
  '策略': [
    {'key': 'sourcetype', 'label': '策略来源(index)', 'type': 'int'},
    {'key': 'zh_ids', 'label': 'XX策略', 'type': 'text'},
    {'key': 'dc_id', 'label': 'DD策略', 'type': 'text'},
    {'key': 'dcsp_id', 'label': 'DS实盘', 'type': 'text'},
    {'key': 'strategies', 'label': '聚宽策略', 'type': 'text'},
    {'key': 'combinationId', 'label': 'DS/DSS策略ID', 'type': 'text'},
    {'key': 'zh_assets', 'label': '策略资金', 'type': 'text'},
    {'key': 'black_stock', 'label': '黑名单', 'type': 'text'},
  ],
  '账号密钥': [
    {'key': 'licence', 'label': '序列号', 'type': 'text'},
    {'key': 'userid', 'label': 'XXID', 'type': 'text'},
    {'key': 'cookies', 'label': 'XXcookies', 'type': 'text'},
    {'key': 'username', 'label': '聚宽ID', 'type': 'text'},
    {'key': 'password', 'label': '聚宽密码', 'type': 'text'},
    {'key': 'combinationName', 'label': 'DDID', 'type': 'text'},
    {'key': 'signs', 'label': '同花路径', 'type': 'text'},
  ],
  '通道': [
    {'key': 'clienttype', 'label': '交易通道(index)', 'type': 'int'},
    {'key': 'pos_kind', 'label': '查仓方式(index)', 'type': 'int'},
    {'key': 'dc_account', 'label': '东财账号', 'type': 'text'},
    {'key': 'dc_pwd', 'label': '东财密码', 'type': 'text'},
    {'key': 'gh_account', 'label': '国海账号', 'type': 'text'},
    {'key': 'gh_pwd', 'label': '国海密码', 'type': 'text'},
    {'key': 'gh_uuid', 'label': '国海UUID', 'type': 'text'},
    {'key': 'qmt_acc', 'label': 'QMT账号', 'type': 'text'},
    {'key': 'qmt_path', 'label': 'QMT Path', 'type': 'text'},
  ],
  '基础': [
    {'key': 'cmd_expired', 'label': '指令过期', 'type': 'text'},
    {'key': 'track_interval', 'label': '轮询间隔', 'type': 'text'},
    {'key': 'send_interval', 'label': '买卖间隔', 'type': 'text'},
    {'key': 'buy_slippage', 'label': '买滑点', 'type': 'text'},
    {'key': 'sell_slippage', 'label': '卖滑点', 'type': 'text'},
    {'key': 'buy_wujia', 'label': '买五价(index)', 'type': 'int'},
    {'key': 'sell_wujia', 'label': '卖五价(index)', 'type': 'int'},
    {'key': 'trade_choice', 'label': '滑点/五价(index)', 'type': 'int'},
    {'key': 'sequence', 'label': '提速选择(index)', 'type': 'int'},
    {'key': 'wxPushUID', 'label': '微信UID', 'type': 'text'},
  ],
  '开关': [
    {'key': 'stop', 'label': '定时停止', 'type': 'bool'},
    {'key': 'cmd_cache', 'label': '读取历史指令', 'type': 'bool'},
    {'key': 'scitech', 'label': '屏蔽科创板', 'type': 'bool'},
    {'key': 'chinext', 'label': '屏蔽创业板', 'type': 'bool'},
    {'key': 'wxPush', 'label': '微信推送', 'type': 'bool'},
    {'key': 'fundEnable', 'label': '买查资', 'type': 'bool'},
    {'key': 'posEnable', 'label': '卖查仓', 'type': 'bool'},
    {'key': 'thsDefaultNull', 'label': '控价抢筹', 'type': 'bool'},
  ],
};
