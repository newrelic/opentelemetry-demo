package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func handleK8s(action string, cfg *Config) {
	checkTools("kubectl", "helm")
	// Namespace
	ns := Charts["otel-demo"].NS

	if action == "uninstall" {
		// Use runCommand so output is visible to the user
		runCommand("helm", []string{"uninstall", Charts["otel-demo"].Name, "-n", ns}, nil)
		runCommand("helm", []string{"uninstall", Charts["nr-k8s"].Name, "-n", ns}, nil)
		runCommand("kubectl", []string{"delete", "ns", ns}, nil)
		return
	}
	// Explicitly ask if the user wants to enable Browser Monitoring every time.
	// FIX: Only prompt if the flag wasn't already provided
	if cfg.EnableBrowser == nil {
		enableBrowser := promptBool("Do you want to enable Digital Experience Monitoring (Browser)?")
		cfg.EnableBrowser = &enableBrowser
	}

	if *cfg.EnableBrowser {
		if cfg.ApiKey == "" {
			// Make sure we have the keys BEFORE calling Terraform to avoid broken prompts
			cfg.ApiKey = promptUser("Enter your User API Key (NRAK)", validateNotEmpty)
		}
		if cfg.AccountId == "" {
			cfg.AccountId = promptUser("Enter your New Relic Account ID", validateNotEmpty)
		}
		fmt.Println("\n>>> Setting up Browser Monitoring (Terraform)...")
		handleTerraform("install", "browser", cfg)
	}

	runCommand("helm", []string{"repo", "add", "newrelic", "https://helm-charts.newrelic.com"}, nil)
	runCommand("helm", []string{"repo", "add", "open-telemetry", "https://open-telemetry.github.io/opentelemetry-helm-charts"}, nil)
	runCommand("helm", []string{"repo", "update"}, nil)

	detectOpenShift()
	exec.Command("kubectl", "create", "ns", ns).Run()

	exec.Command("kubectl", "delete", "secret", "newrelic-license-key", "-n", ns).Run()
	runCommand("kubectl", []string{"create", "secret", "generic", "newrelic-license-key", "--from-literal=license-key=" + cfg.LicenseKey, "-n", ns}, nil)

	installChart("nr-k8s", []string{Paths["nr-k8s-values"]}, cfg)

	otelValues := []string{Paths["otel-values"]}
	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		otelValues = append(otelValues, Paths["otel-browser-values"])
	}
	installChart("otel-demo", otelValues, cfg)
}

func installChart(key string, values []string, cfg *Config) {
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

func detectOpenShift() {
	out, err := exec.Command("kubectl", "api-versions").Output()
	if err == nil && strings.Contains(string(out), "security.openshift.io") {
		isOpenShift = true
		fmt.Println("OpenShift detected.")
	}
}
