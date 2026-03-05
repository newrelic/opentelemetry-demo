package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// handleDocker manages Docker Compose deployment and Browser instrumentation.
func handleDocker(action string, cfg *Config) {
	checkTools("docker")

	basePath := Paths["docker-compose"]
	envPath := filepath.Join("..", "..", ".env")
	envOverridePath := filepath.Join("..", "..", ".env.override")

	args := []string{"compose"}

	if _, err := os.Stat(envPath); err == nil {
		args = append(args, "--env-file", envPath)
	}
	if _, err := os.Stat(envOverridePath); err == nil {
		args = append(args, "--env-file", envOverridePath)
	}

	args = append(args, "-f", basePath)

	if action == "uninstall" {
		args = append(args, "down", "-v")
		env := append(os.Environ(), "NEW_RELIC_LICENSE_KEY=DUMMY_LICENSE_KEY")
		runCommand("docker", args, env)
		return
	}

	// Browser setup logic: executes only if enabled
	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		if cfg.BrowserAppID == "" {
			fmt.Println("\n>>> Setting up Browser Monitoring (Terraform)...")
			oldTarget := cfg.Target
			cfg.Target = "browser"
			handleTerraform("install", cfg)
			cfg.Target = oldTarget
		} else {
			fmt.Println("\n>>> Browser configuration found, skipping Terraform.")
		}
	}

	if cfg.EnableBrowser != nil && *cfg.EnableBrowser {
		fmt.Println("\n>>> Injecting Browser IDs into Docker Patch...")
		contentBytes, err := os.ReadFile(Paths["docker-patch"])
		if err == nil {
			content := string(contentBytes)
			content = strings.ReplaceAll(content, "$LICENSE_KEY", cfg.BrowserLicenseKey)
			content = strings.ReplaceAll(content, "$APPLICATION_ID", cfg.BrowserAppID)
			content = strings.ReplaceAll(content, "$ACCOUNT_ID", cfg.BrowserAccountID)
			content = strings.ReplaceAll(content, "$TRUST_KEY", cfg.BrowserTrustKey)
			content = strings.ReplaceAll(content, "$AGENT_ID", cfg.BrowserAgentID)

			injectedPatchPath := filepath.Join(filepath.Dir(Paths["docker-patch"]), "monkey-patch-injected.js")
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
			args = append(args, "-f", overrideYamlPath)
		}
	}

	args = append(args, "up", "--force-recreate", "--remove-orphans", "--detach")
	env := append(os.Environ(), "NEW_RELIC_LICENSE_KEY="+cfg.LicenseKey)
	runCommand("docker", args, env)

	saveConfigToEnv(cfg)
}
