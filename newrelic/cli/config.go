package main

import (
	"fmt"
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

	// Global capture of shell environment for restoration after uninstall
	InitialLicenseKey string
	InitialAccountId  string

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
	LicenseKey, ApiKey, AccountId, Region, Target, Action                              string
	EnableBrowser                                                                      *bool
	SubAccountId                                                                       string
	ParentAccountId                                                                    string
	SubaccountName, AdminGroupName                                                     string
	ReadonlyUserEmail, ReadonlyUserName                                                string
	BrowserLicenseKey, BrowserAppID, BrowserAccountID, BrowserTrustKey, BrowserAgentID string
}

// CaptureInitialEnv stores the shell's variables before .env loads
func CaptureInitialEnv() {
	InitialLicenseKey = os.Getenv("NEW_RELIC_LICENSE_KEY")
	InitialAccountId = os.Getenv("NEW_RELIC_ACCOUNT_ID")
}

func loadConfig(cfg *Config) {
	// 1. Load .env file preserving original case for Terraform compatibility
	if envData, err := os.ReadFile(".env"); err == nil {
		lines := strings.Split(string(envData), "\n")
		for _, line := range lines {
			pair := strings.SplitN(line, "=", 2)
			if len(pair) == 2 {
				key := strings.TrimSpace(pair[0])
				val := strings.TrimSpace(pair[1])
				os.Setenv(key, val)
			}
		}
	}

	if cfg.Region == "" {
		cfg.Region = strings.ToUpper(getEnvOrDefault("NEW_RELIC_REGION", "US"))
	}

	// Helper to check both uppercase and lowercase suffixes for TF_VARs
	getTFVar := func(suffix string) string {
		val := os.Getenv("TF_VAR_" + suffix)
		if val == "" {
			val = os.Getenv("TF_VAR_" + strings.ToUpper(suffix))
		}
		return val
	}

	// 2. Populate fields from Environment (Standardizing to match Config struct)
	if cfg.LicenseKey == "" {
		cfg.LicenseKey = os.Getenv("NEW_RELIC_LICENSE_KEY")
	}
	if cfg.ApiKey == "" {
		cfg.ApiKey = os.Getenv("NEW_RELIC_API_KEY")
	}
	if cfg.AccountId == "" {
		cfg.AccountId = os.Getenv("NEW_RELIC_ACCOUNT_ID")
	}

	// Meta and Terraform Vars (Lowercase suffixes for variables.tf alignment)
	if cfg.SubAccountId == "" {
		cfg.SubAccountId = getTFVar("newrelic_account_id")
	}
	if cfg.ParentAccountId == "" {
		cfg.ParentAccountId = getTFVar("newrelic_parent_account_id")
	}
	if cfg.SubaccountName == "" {
		cfg.SubaccountName = getTFVar("subaccount_name")
	}
	if cfg.AdminGroupName == "" {
		cfg.AdminGroupName = getTFVar("admin_group_name")
	}
	if cfg.ReadonlyUserEmail == "" {
		cfg.ReadonlyUserEmail = getTFVar("readonly_user_email")
	}
	if cfg.ReadonlyUserName == "" {
		cfg.ReadonlyUserName = getTFVar("readonly_user_name")
	}

	// Browser fields from OS/Env
	if cfg.BrowserLicenseKey == "" {
		cfg.BrowserLicenseKey = os.Getenv("BROWSER_LICENSE_KEY")
	}
	if cfg.BrowserAppID == "" {
		cfg.BrowserAppID = os.Getenv("BROWSER_APPLICATION_ID")
	}
	if cfg.BrowserAccountID == "" {
		cfg.BrowserAccountID = os.Getenv("BROWSER_ACCOUNT_ID")
	}
	if cfg.BrowserTrustKey == "" {
		cfg.BrowserTrustKey = os.Getenv("BROWSER_TRUST_KEY")
	}
	if cfg.BrowserAgentID == "" {
		cfg.BrowserAgentID = os.Getenv("BROWSER_AGENT_ID")
	}

	// 3. Populate EnableBrowser from Flag/Env
	if cfg.EnableBrowser == nil {
		if envVal := os.Getenv("NEW_RELIC_ENABLE_BROWSER"); envVal != "" {
			b := strings.ToLower(envVal) == "true"
			cfg.EnableBrowser = &b
		}
	}

	if cfg.Action == "uninstall" {
		return
	}

	// 4. Consolidated Browser Prompt (Asked once here if still unknown)
	if cfg.EnableBrowser == nil && (cfg.Target == "k8s" || cfg.Target == "docker") {
		fmt.Println("\n>>> Browser Monitoring configuration missing.")
		enable := promptBool("Do you want to enable Digital Experience Monitoring (Browser)?")
		cfg.EnableBrowser = &enable
	}

	// Standard prompts for K8s/Docker
	if cfg.Target == "k8s" || cfg.Target == "docker" {
		if cfg.LicenseKey == "" {
			cfg.LicenseKey = promptUser("Enter your License Key (ends in -NRAL)", validateLicenseKey)
		}

		// If Browser is enabled, we MUST have API Key and Account ID for the Terraform step
		if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
			if cfg.ApiKey == "" {
				cfg.ApiKey = promptUser("Enter your User API Key (begins with NRAK-)", validateUserApiKey)
			}
			if cfg.AccountId == "" {
				cfg.AccountId = promptUser("Enter your New Relic Account ID", validateNotEmpty)
			}
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
		if cfg.ReadonlyUserEmail == "" {
			cfg.ReadonlyUserEmail = promptUser("New Read-Only User Email", validateNotEmpty)
		}
		if cfg.ReadonlyUserName == "" {
			cfg.ReadonlyUserName = promptUser("New Read-Only User Name", validateNotEmpty)
		}
	}
}
