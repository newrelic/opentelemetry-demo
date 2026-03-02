package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func handleDocker(action string, cfg *Config) {
	checkTools("docker")

	// 1. Define paths
	basePath := Paths["docker-compose"]
	envPath := filepath.Join("..", "..", ".env")
	envOverridePath := filepath.Join("..", "..", ".env.override")

	// 2. Build base Docker Compose arguments
	args := []string{"compose"}

	if _, err := os.Stat(envPath); err == nil {
		args = append(args, "--env-file", envPath)
	}
	if _, err := os.Stat(envOverridePath); err == nil {
		args = append(args, "--env-file", envOverridePath)
	}

	args = append(args, "-f", basePath)

	// 3. Handle Uninstall Early
	if action == "uninstall" {
		args = append(args, "down", "-v")
		env := append(os.Environ(), "NEW_RELIC_LICENSE_KEY=uninstall_dummy")
		runCommand("docker", args, env)
		return
	}

	// 4. Browser Setup & Terraform
	// FIX: Only prompt if the flag wasn't already provided
	if cfg.EnableBrowser == nil {
		enableBrowser := promptBool("Do you want to enable Digital Experience Monitoring (Browser)?")
		cfg.EnableBrowser = &enableBrowser
	}

	if *cfg.EnableBrowser {
		if cfg.ApiKey == "" {
			cfg.ApiKey = promptUser("User API Key (NRAK)", validateUserApiKey)
		}
		if cfg.AccountId == "" {
			cfg.AccountId = promptUser("New Relic Account ID", validateNotEmpty)
		}

		fmt.Println("\n>>> 🌍 Setting up Browser Monitoring (Terraform)...")
		handleTerraform("install", "browser", cfg)
	}

	// 5. Generate Permanent Patched Files
	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		fmt.Println("\n>>> Injecting Browser IDs into Docker Patch...")

		tfPath := Paths["tf-browser"]
		tfEnv := buildEnvMap(cfg)

		// Fetch js_config JSON from Terraform
		cmd := exec.Command("terraform", "-chdir="+tfPath, "output", "-json", "browser_js_config")
		cmd.Env = tfEnv
		out, err := cmd.Output()
		if err != nil {
			fmt.Printf("Warning: Failed to read browser_js_config: %v\n", err)
		}

		var tfOutput string
		json.Unmarshal(out, &tfOutput)

		var nrConfig BrowserConfig
		json.Unmarshal([]byte(tfOutput), &nrConfig)

		// Fetch License Key from Terraform
		cmdKey := exec.Command("terraform", "-chdir="+tfPath, "output", "-raw", "browser_license_key")
		cmdKey.Env = tfEnv
		outKey, _ := cmdKey.Output()
		licenseKey := strings.TrimSpace(string(outKey))

		// Read the base monkey-patch.js
		originalPatchPath := Paths["docker-patch"]
		contentBytes, err := os.ReadFile(originalPatchPath)
		if err != nil {
			fmt.Printf("Error reading original patch: %v\n", err)
		}
		content := string(contentBytes)

		// Replace placeholders
		content = strings.ReplaceAll(content, "$LICENSE_KEY", licenseKey)
		content = strings.ReplaceAll(content, "$APPLICATION_ID", formatID(nrConfig.Info.AppID))
		content = strings.ReplaceAll(content, "$ACCOUNT_ID", formatID(nrConfig.LoaderConfig.AccountID))
		content = strings.ReplaceAll(content, "$TRUST_KEY", formatID(nrConfig.LoaderConfig.TrustKey))
		content = strings.ReplaceAll(content, "$AGENT_ID", formatID(nrConfig.LoaderConfig.AgentID))

		// Write to a PERMANENT file with safe 0644 permissions
		injectedPatchPath := filepath.Join(filepath.Dir(originalPatchPath), "monkey-patch-injected.js")
		os.WriteFile(injectedPatchPath, []byte(content), 0644)

		overrideYamlPath := filepath.Join(filepath.Dir(basePath), "docker-compose-browser.yaml")
		overrideContent := `
services:
  frontend:
    volumes:
      - ./config/monkey-patch-injected.js:/app/monkey-patch.js:z
    command:
      - "--require=./Instrumentation.js"
      - "--require=./monkey-patch.js"
      - "server.js"
`
		os.WriteFile(overrideYamlPath, []byte(overrideContent), 0644)

		// Tell Docker to use this new file
		args = append(args, "-f", overrideYamlPath)
	}

	// 6. Final execution arguments
	args = append(args, "up", "--force-recreate", "--remove-orphans", "--detach")

	env := append(os.Environ(), "NEW_RELIC_LICENSE_KEY="+cfg.LicenseKey)

	fmt.Printf("\n>>> Running Docker Compose...\n")
	runCommand("docker", args, env)
}
