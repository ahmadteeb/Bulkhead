/// Keep CLI operations on the same engine selected for socket requests.
String dockerHost(String endpoint) {
  if (endpoint.startsWith('http://')) {
    return endpoint.replaceFirst('http://', 'tcp://');
  }
  if (endpoint.contains('://')) return endpoint;
  if (endpoint.startsWith(r'\\.\pipe\')) {
    return 'npipe://${endpoint.replaceAll(r'\', '/')}';
  }
  return 'unix://$endpoint';
}

Map<String, String> dockerEnvironment(String endpoint) => {
  'DOCKER_HOST': dockerHost(endpoint),
  // An inherited Docker context overrides DOCKER_HOST.
  'DOCKER_CONTEXT': '',
  'DOCKER_TLS_VERIFY': '',
  'DOCKER_CERT_PATH': '',
};

String shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";
