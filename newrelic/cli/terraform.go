package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type BrowserConfig struct {
	Info struct {
		AppID interface{} `json:"applicationID"`
	} `json:"info"`
	LoaderConfig struct {
		AccountID interface{} `json:"accountID"`
		TrustKey  interface{} `json:"trustKey"`
		AgentID   interface{} `json:"agentID"`
		AppID     interface{} `json:"applicationID"`
	} `json:"loader_config"`
}

type TemplateData struct {
	LicenseKey string
	AppID      string
	AccountID  string
	TrustKey   string
	AgentID    string
}

func handleTerraform(action string, cfg *Config) {
	checkTools("terraform", "jq")

	var tfPath string
	switch cfg.Target {
	case "account":
		tfPath = Paths["tf-account"]
	case "resources":
		tfPath = Paths["tf-resources"]
	case "browser":
		tfPath = Paths["tf-browser"]
	default:
		tfPath = Paths["tf-browser"]
	}

	env := buildEnvMap(cfg)
	tfArgs := []string{"-chdir=" + tfPath}
	autoApprove := "-auto-approve"

	if action == "uninstall" {
		runCommand("terraform", append(tfArgs, "destroy", autoApprove), env)

		if cfg.Target == "account" {
			fmt.Println("\n>>> Restoring environment and clearing sub-account/browser metadata...")

			// 1. Memory Cleanup
			keysToClear := []string{
				"NEW_RELIC_ACCOUNT_ID", "NEW_RELIC_LICENSE_KEY",
				"TF_VAR_SUBACCOUNT_NAME", "TF_VAR_ADMIN_GROUP_NAME",
				"TF_VAR_READONLY_USER_NAME", "TF_VAR_READONLY_USER_EMAIL",
				"BROWSER_LICENSE_KEY", "BROWSER_APPLICATION_ID",
				"BROWSER_ACCOUNT_ID", "BROWSER_TRUST_KEY", "BROWSER_AGENT_ID",
			}
			for _, k := range keysToClear {
				os.Unsetenv(k)
			}

			// 2. Restoration Logic (Flag > Initial Capture > Reset)
			cmdCfg, _ := parseArgs()

			// Account ID
			if cmdCfg.AccountId != "" {
				cfg.AccountId = cmdCfg.AccountId
			} else if InitialAccountId != "" {
				cfg.AccountId = InitialAccountId
			} else {
				cfg.AccountId = ""
			}

			// License Key
			if cmdCfg.LicenseKey != "" {
				cfg.LicenseKey = cmdCfg.LicenseKey
			} else if InitialLicenseKey != "" {
				cfg.LicenseKey = InitialLicenseKey
			} else {
				cfg.LicenseKey = ""
			}

			// 3. Struct Reset
			cfg.SubAccountId = ""
			cfg.ParentAccountId = ""
			cfg.SubaccountName = ""
			cfg.AdminGroupName = ""
			cfg.ReadonlyUserName = ""
			cfg.ReadonlyUserEmail = ""
			cfg.BrowserLicenseKey = ""
			cfg.BrowserAppID = ""
			cfg.BrowserAccountID = ""
			cfg.BrowserTrustKey = ""
			cfg.BrowserAgentID = ""

			// Update process memory for UI
			if cfg.AccountId != "" {
				os.Setenv("NEW_RELIC_ACCOUNT_ID", cfg.AccountId)
			}
			if cfg.LicenseKey != "" {
				os.Setenv("NEW_RELIC_LICENSE_KEY", cfg.LicenseKey)
			}

			saveConfigToEnv(cfg)
		}
		return
	}

	if err := runCommand("terraform", append(tfArgs, "init"), env); err != nil {
		return
	}

	if cfg.Target == "account" {
		runCommand("terraform", append(tfArgs, "apply", "-target=newrelic_account_management.subaccount", autoApprove), env)
		out, _ := exec.Command("terraform", append(tfArgs, "output", "-raw", "account_id")...).Output()
		if id := strings.TrimSpace(string(out)); id != "" {
			if cfg.ParentAccountId == "" {
				cfg.ParentAccountId = cfg.AccountId
			}
			cfg.SubAccountId = id
			cfg.AccountId = id
			env = buildEnvMap(cfg)
		}
	}

	if err := runCommand("terraform", append(tfArgs, "apply", autoApprove), env); err != nil {
		return
	}

	if cfg.Target == "account" {
		out, _ := exec.Command("terraform", append(tfArgs, "output", "-raw", "license_key")...).Output()
		cfg.LicenseKey = strings.TrimSpace(string(out))
	} else if cfg.Target == "browser" {
		fetchBrowserConfigFromTF(tfArgs, env, cfg)
	}

	saveConfigToEnv(cfg)
}

func buildEnvMap(cfg *Config) []string {
	parentID := cfg.ParentAccountId
	if parentID == "" {
		parentID = cfg.AccountId
	}

	accountID := cfg.SubAccountId
	if accountID == "" {
		accountID = cfg.AccountId
	}

	env := os.Environ()
	// Keys MUST match variables.tf suffixes in lowercase
	mapping := map[string]string{
		"TF_VAR_newrelic_api_key":           cfg.ApiKey,
		"TF_VAR_newrelic_parent_account_id": parentID,
		"TF_VAR_newrelic_account_id":        accountID,
		"TF_VAR_newrelic_region":            cfg.Region,
		"TF_VAR_subaccount_name":            cfg.SubaccountName,
		"TF_VAR_admin_group_name":           cfg.AdminGroupName,
		"TF_VAR_readonly_user_email":        cfg.ReadonlyUserEmail,
		"TF_VAR_readonly_user_name":         cfg.ReadonlyUserName,
	}
	for k, v := range mapping {
		if v != "" {
			env = append(env, k+"="+v)
		}
	}
	return env
}

func formatID(v interface{}) string {
	switch val := v.(type) {
	case float64:
		return fmt.Sprintf("%.0f", val)
	case string:
		return val
	default:
		return fmt.Sprintf("%v", val)
	}
}
