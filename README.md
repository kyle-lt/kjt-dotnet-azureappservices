# OpenTelemetry .NET for Azure App Service, zero-code

Traces, metrics and logs from .NET apps on **Azure App Service**, with no change to your code and no rebuild. These installers put an unmodified OpenTelemetry .NET distribution into your app and switch it on. You send the data wherever you like: any OTLP endpoint, or Splunk Observability Cloud.

Distributions: upstream, splunk.

*Not affiliated with or endorsed by the OpenTelemetry project, and, for the Splunk distribution, not an official Splunk product or supported by Splunk.*

| Your app runs on | Use |
|---|---|
| **Windows** App Service | the site extension, from the portal's **Extensions** list ([below](#windows)) |
| **Linux** App Service, built-in .NET image | **Deploy to Azure**, one command in Cloud Shell, Bicep or Terraform ([below](#linux)) |

## Windows

In the portal, open your app → **Development Tools → Extensions → + Add**, pick the extension, and accept. Then set where to send data (see [Where to send data](#where-to-send-data)) and **Stop**, then **Start** the app.

| Distribution | Site extension (nuget.org) |
|---|---|
| OpenTelemetry .NET automatic instrumentation | [Kjt.DotNet.AzureAppServices.Extension](https://www.nuget.org/packages/Kjt.DotNet.AzureAppServices.Extension) |
| Splunk Distribution of OpenTelemetry .NET | [Kjt.DotNet.AzureAppServices.Extension.Splunk](https://www.nuget.org/packages/Kjt.DotNet.AzureAppServices.Extension.Splunk) |

Each package's page on nuget.org has the full instructions. Install **one** of them per app.

## Linux

Each way below does the same two things, in this order:

1. It puts the distribution's own release onto your app's `/home`, at `/home/otel/<distro>/<version>`.
2. It adds the App Settings that switch it on, **merged with your existing ones**.

Step 2 restarts your app, and that start finds the files already there. So the very first start is instrumented, with no extra restart.

### Option 1: Deploy to Azure

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fkyle-lt%2Fkjt-dotnet-azureappservices%2Fmain%2Flinux%2Fazuredeploy.json)

Pick the **resource group your app is in**, type the app's name, choose a distribution, then **Review + create**.

If the deployment fails at the `onedeploy` step with an *internal server error*, **redeploy it**. Azure intermittently reports that even when the copy went through (seen once in four test deployments). Nothing is switched on until the deployment succeeds, so your app is unaffected meanwhile. The same applies to Bicep and to `terraform apply`. To choose the app from a list instead, see [#30](https://github.com/kyle-lt/OtelSiteExtension/issues/30) (planned).

### Option 2: one command in Cloud Shell

Open **Cloud Shell** (Bash) in the Azure portal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/kyle-lt/kjt-dotnet-azureappservices/main/linux/install.sh | bash -s -- -g <resource-group> -n <app> --distro upstream
```

Use `--distro splunk` for the Splunk distribution. The script:
- checks that the app is a Linux .NET app with no other .NET profiler configured;
- downloads the release and verifies its **sha256** against the pinned value;
- pushes it onto `/home` through Kudu (skipped if that version is already there);
- merges the settings.

`--dry-run` shows what it would do, `--slot <name>` targets a deployment slot, and `--uninstall` removes the settings again. It prints the exact next step for sending data.

### Option 3: Bicep

```bash
curl -fsSLO https://raw.githubusercontent.com/kyle-lt/kjt-dotnet-azureappservices/main/linux/bicep/otel-dotnet-linux.bicep
curl -fsSLO https://raw.githubusercontent.com/kyle-lt/kjt-dotnet-azureappservices/main/linux/bicep/otel-appsettings.bicep
az deployment group create -g <resource-group> -f otel-dotnet-linux.bicep -p appName=<app> distro=upstream
```

[`linux/azuredeploy.json`](linux/azuredeploy.json) is the same template compiled to ARM, and it's what the button deploys.

### Option 4: Terraform (azapi)

```hcl
module "otel" {
  source = "git::https://github.com/kyle-lt/kjt-dotnet-azureappservices.git//linux/terraform?ref=main"   # pin a commit SHA for production
  app_id = azurerm_linux_web_app.app.id
  distro = "upstream"
}

resource "azurerm_linux_web_app" "app" {
  # ...
  app_settings = merge(local.my_app_settings, module.otel.app_settings)
}
```

Your web app keeps owning its settings; the module only outputs them. It unzips the release onto `/home` and then restarts the app once, so the app ends up instrumented whichever order Terraform applied things in.

## Where to send data

The installers switch instrumentation on. **Where the data goes is yours to set**, as App Settings: `OTEL_EXPORTER_OTLP_ENDPOINT` (with `OTEL_EXPORTER_OTLP_HEADERS` if needed), or for Splunk `SPLUNK_REALM` and `SPLUNK_ACCESS_TOKEN`. Add `OTEL_SERVICE_NAME` too. Without them the exporter targets a local collector that doesn't exist on App Service.

## Good to know (Linux)

- **The settings it adds** come from the distribution's own `instrument.sh`, with two differences:
  - **`DOTNET_STARTUP_HOOKS` is not set.** The instrumentation adds its startup hook itself, and if the files were ever missing, that setting would crash your app instead of letting it run uninstrumented.
  - **`OTEL_DOTNET_AUTO_EXCLUDE_PROCESSES=DiagServer` is added,** merged into any exclusions you already have (`install.sh`, Bicep and the button do that; with Terraform, keep `DiagServer` in the list you set). It keeps the instrumentation out of App Service's own .NET diagnostics process, which fails when instrumented.
- **One .NET profiler per app.** `install.sh` refuses if another one is configured (`CORECLR_PROFILER` set to a different value). **The button, Bicep and Terraform don't check:** they would replace it, and the other agent (Application Insights' or another vendor's) would silently stop working. Check `CORECLR_PROFILER` before you use them.
- **Provenance:** `install.sh` verifies the sha256 itself. With the button, Bicep and Terraform, App Service fetches the distribution's tag-pinned GitHub release directly.
- **Updating:** run it again when a newer version is published here. That installs into a new directory and points the settings at it. The old directory stays until you delete it from Kudu.
- **Checking it works:** set `OTEL_DOTNET_AUTO_LOG_DIRECTORY=/home/LogFiles/otel`. In Kudu, `*-dotnet-Native.log` should say `Profiler attached`.

## License

Apache-2.0 (see [LICENSE](LICENSE)). The distributions keep their own licenses.

<sub>Everything here is generated and published by the build from the pinned, attested releases; changes made directly to this repository are overwritten.</sub>
