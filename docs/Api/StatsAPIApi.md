# IONOS\NextcloudPSS\AddonsAPI\Client\Api\StatsAPIApi

All URIs are relative to https://API_HOST/nextcloud, except if the operation defines another base path.

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**updateStats()**](StatsAPIApi.md#updateStats) | **PUT** /addons/{brand}/{extRef}/stats | Reports the current active user count from the Nextcloud instance to PSS |


## `updateStats()`

```php
updateStats($brand, $extRef, $statsUpdateRequest)
```

Reports the current active user count from the Nextcloud instance to PSS

### Example

```php
<?php
require_once(__DIR__ . '/vendor/autoload.php');


// Configure HTTP basic authorization: basicAuth
$config = IONOS\NextcloudPSS\AddonsAPI\Client\Configuration::getDefaultConfiguration()
              ->setUsername('YOUR_USERNAME')
              ->setPassword('YOUR_PASSWORD');



$apiInstance = new IONOS\NextcloudPSS\AddonsAPI\Client\Api\StatsAPIApi(
    // If you want use custom http client, pass your client which implements `GuzzleHttp\ClientInterface`.
    // This is optional, `GuzzleHttp\Client` will be used as default.
    new GuzzleHttp\Client(),
    $config
);
$brand = 'IONOS'; // string
$extRef = 'extRef_example'; // string

$users = new \IONOS\NextcloudPSS\AddonsAPI\Client\Model\UserStats();
$users->setExistingUsers(42);

$statsUpdateRequest = new \IONOS\NextcloudPSS\AddonsAPI\Client\Model\StatsUpdateRequest();
$statsUpdateRequest->setTimestamp(new \DateTime());
$statsUpdateRequest->setUsers($users);

try {
    $apiInstance->updateStats($brand, $extRef, $statsUpdateRequest);
} catch (Exception $e) {
    echo 'Exception when calling StatsAPIApi->updateStats: ', $e->getMessage(), PHP_EOL;
}
```

### Parameters

| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **brand** | **string**|  | |
| **extRef** | **string**|  | |
| **statsUpdateRequest** | [**\IONOS\NextcloudPSS\AddonsAPI\Client\Model\StatsUpdateRequest**](../Model/StatsUpdateRequest.md)|  | |

### Return type

void (empty response body)

### Authorization

[basicAuth](../../README.md#basicAuth)

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`

[[Back to top]](#) [[Back to API list]](../../README.md#endpoints)
[[Back to Model list]](../../README.md#models)
[[Back to README]](../../README.md)
