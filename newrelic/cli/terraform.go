package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"
)

// BrowserConfig structure to parse the 'js_config' output from Terraform
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

// TemplateData holds the finalized strings to inject into the YAML
type TemplateData struct {
	LicenseKey string
	AppID      string
	AccountID  string
	TrustKey   string
	AgentID    string
}

func handleTerraform(action, target string, cfg *Config) {
	checkTools("terraform", "jq")

	var tfPath string
	switch target {
	case "account":
		tfPath = Paths["tf-account"]
	case "resources":
		tfPath = Paths["tf-resources"]
	case "browser":
		tfPath = Paths["tf-browser"]
	}

	env := buildEnvMap(cfg)
	tfArgs := []string{"-chdir=" + tfPath}
	autoApprove := "-auto-approve"

	if action == "uninstall" {
		runCommand("terraform", append(tfArgs, "destroy", autoApprove), env)
		return
	}

	if err := runCommand("terraform", append(tfArgs, "init"), env); err != nil {
		return
	}

	if target == "account" {
		runCommand("terraform", append(tfArgs, "apply", "-target=newrelic_account_management.subaccount", autoApprove), env)
		out, _ := exec.Command("terraform", append(tfArgs, "output", "-raw", "account_id")...).Output()
		if id := strings.TrimSpace(string(out)); id != "" {
			fmt.Printf("Captured New Sub-Account ID: %s\n", id)
			cfg.AccountId = id
			env = buildEnvMap(cfg)
		}
	}

	if err := runCommand("terraform", append(tfArgs, "apply", autoApprove), env); err != nil {
		return
	}

	if target == "account" {
		out, err := exec.Command("terraform", append(tfArgs, "output", "-raw", "license_key")...).Output()
		if err == nil {
			licenseKey := strings.TrimSpace(string(out))
			if licenseKey != "" {
				cfg.LicenseKey = licenseKey
				os.Setenv("NEW_RELIC_LICENSE_KEY", licenseKey)
			}
		}
	} else if target == "browser" {
		injectBrowserConfig(tfArgs, env)
	}
}

func buildEnvMap(cfg *Config) []string {
	env := os.Environ()
	mapping := map[string]string{
		"TF_VAR_newrelic_api_key":           cfg.ApiKey,
		"TF_VAR_newrelic_parent_account_id": cfg.AccountId,
		"TF_VAR_newrelic_account_id":        cfg.AccountId,
		"TF_VAR_newrelic_region":            cfg.Region,
		"TF_VAR_subaccount_name":            cfg.SubaccountName,
		"TF_VAR_admin_group_name":           cfg.AdminGroupName,
		"TF_VAR_user_email":                 cfg.UserEmail,
		"TF_VAR_user_name":                  cfg.UserName,
	}
	for k, v := range mapping {
		if v != "" {
			env = append(env, k+"="+v)
		}
	}
	return env
}

// formatID handles the float64 scientific notation issue
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

func injectBrowserConfig(tfArgs []string, env []string) {
	fmt.Println("\n>>> 📦 Configuring Browser Monitoring...")

	// 1. Fetch from Terraform
	cmd := exec.Command("terraform", append(tfArgs, "output", "-json", "browser_js_config")...)
	cmd.Env = env
	out, err := cmd.Output()
	if err != nil {
		fmt.Printf("Error reading browser_js_config: %v\n", err)
		return
	}

	var tfOutput string
	if err := json.Unmarshal(out, &tfOutput); err != nil {
		tfOutput = string(out)
	}

	var nrConfig BrowserConfig
	if err := json.Unmarshal([]byte(tfOutput), &nrConfig); err != nil {
		fmt.Printf("Error parsing js_config JSON: %v\n", err)
		return
	}

	cmdKey := exec.Command("terraform", append(tfArgs, "output", "-raw", "browser_license_key")...)
	cmdKey.Env = env
	outKey, _ := cmdKey.Output()
	licenseKey := strings.TrimSpace(string(outKey))

	// 2. Prepare Template Data
	data := TemplateData{
		LicenseKey: licenseKey,
		AppID:      formatID(nrConfig.Info.AppID),
		AccountID:  formatID(nrConfig.LoaderConfig.AccountID),
		TrustKey:   formatID(nrConfig.LoaderConfig.TrustKey),
		AgentID:    formatID(nrConfig.LoaderConfig.AgentID),
	}

	// 3. Process Template
	yamlPath := Paths["otel-browser-values"] // e.g., newrelic/k8s/helm/nr-browser.yaml
	tmplPath := yamlPath + ".tmpl"           // e.g., newrelic/k8s/helm/nr-browser.yaml.tmpl

	// Check if template exists
	if _, err := os.Stat(tmplPath); os.IsNotExist(err) {
		fmt.Printf("Template file not found at %s. Please create it.\n", tmplPath)
		return
	}

	tmpl, err := template.ParseFiles(tmplPath)
	if err != nil {
		fmt.Printf("Error parsing template: %v\n", err)
		return
	}

	// Output to the real YAML file
	outFile, err := os.Create(yamlPath)
	if err != nil {
		fmt.Printf("Error creating output YAML file: %v\n", err)
		return
	}
	defer outFile.Close()

	if err := tmpl.Execute(outFile, data); err != nil {
		fmt.Printf("Error executing template: %v\n", err)
		return
	}

	fmt.Printf("Successfully generated %s from template!\n", yamlPath)
	fmt.Println("Ready! Run 'install k8s' to deploy.")
}