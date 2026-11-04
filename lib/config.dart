const String appName = '牛来VPN';

String appUpdateEndpoint = const String.fromEnvironment(
  'UPDATE_ENDPOINT',
  defaultValue: 'https://version.vexai.cn/vpn',
);

const List<String> builtInSubscriptionUrls = [
  'https://fuck.vexai.cn:2096/sub/q43if4llj8ayj2hu',
  'https://dp3.config-sync.com/api/v1/client/subscribe?token=c674744ba3424aae02bc31a14e0855a0',
  'https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/v2ray-base64.txt',
  'https://fastly.jsdelivr.net/gh/lanzm/MetaFetch@master/list.b64',
  'https://raw.githubusercontent.com/awesome-vpn/awesome-vpn/master/all',
  'https://735754647.github.io/Free-Nodes/v2ray.txt',
  'https://github.com/firefoxmmx2/v2rayshare_subcription',
];
