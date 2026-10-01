// Merge the activation settings into the app's own App Settings (#28). Part of
// otel-dotnet-linux.bicep; it needs the app's current settings passed in.

param appName string

// @secure, so the app's existing settings (secrets among them) don't land in deployment history.
@secure()
param currentAppSettings object

param otelSettings object

// Settings only the other distributions set, with their values (#43). Switching distro removes those
// the app still holds at exactly that value (Splunk's plugin), and keeps any the operator changed.
param othersSettings array = []

resource site 'Microsoft.Web/sites@2024-04-01' existing = {
  name: appName
}

var kept = toObject(filter(items(currentAppSettings), s => !contains(othersSettings, { name: s.key, value: s.value })), s => s.key, s => s.value)

// OTEL_DOTNET_AUTO_EXCLUDE_PROCESSES is a list: keep the operator's entries and add ours.
var exclude = 'OTEL_DOTNET_AUTO_EXCLUDE_PROCESSES'
var mine = contains(currentAppSettings, exclude) ? split(currentAppSettings[exclude], ',') : []
var merged = union(mine, split(otelSettings[exclude], ','))

resource appsettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: site
  name: 'appsettings'
  properties: union(kept, otelSettings, { '${exclude}': join(filter(merged, p => !empty(trim(p))), ',') })
}
