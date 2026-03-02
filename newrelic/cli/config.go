package main

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	OtelDemoChartVersion = "0.40.2"
	NrK8sChartVersion    = "0.10.0"
	OtelDemoNamespace    = "opentelemetry-demo"
)

var (
	isOpenShift = false

	Paths = map[string]string{
		"otel-values":         filepath.Join("..", "k8s", "helm", "opentelemetry-demo.yaml"),
		"otel-browser-values": filepath.Join("..", "k8s", "helm", "nr-browser.yaml"),
		"nr-k8s-values":       filepath.Join("..", "k8s", "helm", "nr-k8s-otel-collector.yaml"),
		"docker-compose":      filepath.Join("..", "docker", "docker-compose.yml"),
		"docker-patch":        filepath.Join("..", "docker", "config", "monkey-patch.js"),
		"tf-account":          filepath.Join("..", "terraform", "nr_account"),
		"tf-resources":        filepath.Join("..", "terraform", "nr_resources"),
		"tf-browser":          filepath.Join("..", "terraform", "nr_browser"),
	}

	Charts = map[string]struct{ Name, Repo, Version, NS string }{
		"nr-k8s":    {"nr-k8s-otel-collector", "newrelic/nr-k8s-otel-collector", NrK8sChartVersion, OtelDemoNamespace},
		"otel-demo": {"otel-demo", "open-telemetry/opentelemetry-demo", OtelDemoChartVersion, OtelDemoNamespace},
	}
)

type Config struct {
	LicenseKey, ApiKey, AccountId, Region, Target, Action string
	EnableBrowser                                         *bool
	SubaccountName, AdminGroupName                        string
	UserEmail, UserName                                   string
}

func loadConfig(cfg *Config) {
	if cfg.Region == "" {
		cfg.Region = strings.ToUpper(getEnvOrDefault("NEW_RELIC_REGION", "US"))
	}

	if cfg.LicenseKey == "" {
		cfg.LicenseKey = os.Getenv("NEW_RELIC_LICENSE_KEY")
	}
	if cfg.ApiKey == "" {
		cfg.ApiKey = os.Getenv("NEW_RELIC_API_KEY")
	}
	if cfg.AccountId == "" {
		cfg.AccountId = os.Getenv("NEW_RELIC_ACCOUNT_ID")
	}

	if cfg.Action == "uninstall" {
		return
	}

	if cfg.Target == "k8s" || cfg.Target == "docker" {
		if cfg.LicenseKey == "" {
			cfg.LicenseKey = promptUser("License Key (ends in NRAL)", validateLicenseKey)
		}
	}

	if cfg.Target == "account" || cfg.Target == "resources" || cfg.Target == "browser" {
		if cfg.ApiKey == "" {
			cfg.ApiKey = promptUser("User API Key (NRAK)", validateUserApiKey)
		}
		if cfg.AccountId == "" {
			cfg.AccountId = promptUser("Parent Account ID", validateNotEmpty)
		}
	}

	if cfg.Target == "account" {
		if cfg.SubaccountName == "" {
			cfg.SubaccountName = promptUser("New Subaccount Name", validateNotEmpty)
		}
		if cfg.AdminGroupName == "" {
			cfg.AdminGroupName = promptUser("Existing Admin Group Name", validateNotEmpty)
		}
		if cfg.UserEmail == "" {
			cfg.UserEmail = promptUser("New User Email", validateNotEmpty)
		}
		if cfg.UserName == "" {
			cfg.UserName = promptUser("New User Name", validateNotEmpty)
		}
	}
}