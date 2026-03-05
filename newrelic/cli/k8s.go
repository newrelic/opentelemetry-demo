package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"
)

// fetchBrowserConfigFromTF retrieves browser monitoring metadata from Terraform outputs.
func fetchBrowserConfigFromTF(tfArgs []string, env []string, cfg *Config) {
	cmd := exec.Command("terraform", append(tfArgs, "output", "-json", "browser_js_config")...)
	cmd.Env = env
	out, _ := cmd.Output()

	var tfOutput string
	json.Unmarshal(out, &tfOutput)
	var nrConfig BrowserConfig
	json.Unmarshal([]byte(tfOutput), &nrConfig)

	cmdKey := exec.Command("terraform", append(tfArgs, "output", "-raw", "browser_license_key")...)
	cmdKey.Env = env
	outKey, _ := cmdKey.Output()

	cfg.BrowserLicenseKey = strings.TrimSpace(string(outKey))
	cfg.BrowserAppID = formatID(nrConfig.Info.AppID)
	cfg.BrowserAccountID = formatID(nrConfig.LoaderConfig.AccountID)
	cfg.BrowserTrustKey = formatID(nrConfig.LoaderConfig.TrustKey)
	cfg.BrowserAgentID = formatID(nrConfig.LoaderConfig.AgentID)
}

// generateBrowserYaml populates the nr-browser.yaml file using a template.
func generateBrowserYaml(cfg *Config) {
	data := TemplateData{
		LicenseKey: cfg.BrowserLicenseKey,
		AppID:      cfg.BrowserAppID,
		AccountID:  cfg.BrowserAccountID,
		TrustKey:   cfg.BrowserTrustKey,
		AgentID:    cfg.BrowserAgentID,
	}

	yamlPath := Paths["otel-browser-values"]
	tmpl, err := template.ParseFiles(yamlPath + ".tmpl")
	if err != nil {
		fmt.Printf("Error: Template file not found at %s.tmpl\n", yamlPath)
		return
	}
	outFile, _ := os.Create(yamlPath)
	defer outFile.Close()
	tmpl.Execute(outFile, data)
}

// handleK8s manages the Kubernetes installation, upgrade, and uninstallation workflows.
func handleK8s(action string, cfg *Config) {
	checkTools("kubectl", "helm")
	ns := Charts["otel-demo"].NS

	if action == "uninstall" {
		runCommand("helm", []string{"uninstall", Charts["otel-demo"].Name, "-n", ns}, nil)
		runCommand("helm", []string{"uninstall", Charts["nr-k8s"].Name, "-n", ns}, nil)
		runCommand("kubectl", []string{"delete", "ns", ns}, nil)
		return
	}

	// Browser setup logic: executes only if enabled and config is missing
	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		if cfg.BrowserAppID == "" {
			fmt.Println("\n>>> Setting up Browser Monitoring (Terraform)...")
			oldTarget := cfg.Target
			cfg.Target = "browser"
			handleTerraform("install", cfg)
			cfg.Target = oldTarget
			generateBrowserYaml(cfg)
		} else {
			generateBrowserYaml(cfg)
		}
	}

	runCommand("helm", []string{"repo", "add", "newrelic", "https://helm-charts.newrelic.com"}, nil)
	runCommand("helm", []string{"repo", "add", "open-telemetry", "https://open-telemetry.github.io/opentelemetry-helm-charts"}, nil)
	runCommand("helm", []string{"repo", "update", "newrelic", "open-telemetry"}, nil)

	detectOpenShift()
	exec.Command("kubectl", "create", "ns", ns).Run()

	exec.Command("kubectl", "delete", "secret", "newrelic-license-key", "-n", ns).Run()
	runCommand("kubectl", []string{"create", "secret", "generic", "newrelic-license-key", "--from-literal=license-key=" + cfg.LicenseKey, "-n", ns}, nil)

	installChart("nr-k8s", []string{Paths["nr-k8s-values"]})

	otelValues := []string{Paths["otel-values"]}
	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		otelValues = append(otelValues, Paths["otel-browser-values"])
	}
	installChart("otel-demo", otelValues)
}

// installChart executes the helm upgrade --install command for a given chart.
func installChart(key string, values []string) {
	c := Charts[key]
	args := []string{"upgrade", "--install", c.Name, c.Repo, "--version", c.Version, "-n", c.NS}
	for _, v := range values {
		args = append(args, "-f", v)
	}

	if isOpenShift {
		if key == "nr-k8s" {
			args = append(args, "--set", "provider=OPEN_SHIFT")
		}
		if key == "otel-demo" {
			args = append(args, "--set", "serviceAccount.create=false", "--set", "serviceAccount.name="+c.NS)
		}
	}
	runCommand("helm", args, nil)
}

// detectOpenShift checks the cluster for OpenShift-specific API versions.
func detectOpenShift() {
	out, err := exec.Command("kubectl", "api-versions").Output()
	if err == nil && strings.Contains(string(out), "security.openshift.io") {
		isOpenShift = true
		fmt.Println("OpenShift detected.")
	}
}
