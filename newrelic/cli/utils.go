package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func runCommand(name string, args []string, env []string) error {
	fmt.Printf("\x1b[?2004l")
	defer fmt.Printf("\x1b[?2004h")

	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if env != nil {
		cmd.Env = env
	}
	if err := cmd.Run(); err != nil {
		fmt.Printf("Error running %s: %v\n", name, err)
		return err
	}
	return nil
}

func checkTools(tools ...string) {
	for _, t := range tools {
		if _, err := exec.LookPath(t); err != nil {
			fmt.Printf("Error: %s is not installed.\n", t)
			os.Exit(1)
		}
	}
}

func promptUser(label string, validator func(string) error) string {
	fmt.Printf("\x1b[?2004l")
	defer fmt.Printf("\x1b[?2004h")
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("%s: ", label)
		rawInput, _ := reader.ReadString('\n')
		cleanedInput := strings.TrimSpace(rawInput)
		if validator != nil {
			if err := validator(cleanedInput); err != nil {
				fmt.Printf("Invalid input: %v. Please try again.\n", err)
				continue
			}
		}
		if cleanedInput != "" {
			return cleanedInput
		}
	}
}

func promptBool(label string) bool {
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("%s [y/N]: ", label)
		text, _ := reader.ReadString('\n')
		text = strings.TrimSpace(strings.ToLower(text))
		if text == "y" || text == "yes" {
			return true
		}
		if text == "n" || text == "no" || text == "" {
			return false
		}
	}
}

func getEnvOrDefault(key, def string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return def
}

func validateLicenseKey(val string) error {
	if len(val) != 40 || !strings.HasSuffix(val, "NRAL") {
		return fmt.Errorf("must be 40 chars and end with 'NRAL'")
	}
	return nil
}

func validateUserApiKey(val string) error {
	if !strings.HasPrefix(val, "NRAK-") || len(val) != 32 {
		return fmt.Errorf("must start with 'NRAK-' and be 32 chars")
	}
	return nil
}

func validateNotEmpty(val string) error {
	if strings.TrimSpace(val) == "" {
		return fmt.Errorf("value is required")
	}
	return nil
}

func saveConfigToEnv(cfg *Config) {
	envMap := map[string]string{
		"NEW_RELIC_LICENSE_KEY":             cfg.LicenseKey,
		"NEW_RELIC_API_KEY":                 cfg.ApiKey,
		"NEW_RELIC_ACCOUNT_ID":              cfg.AccountId,
		"NEW_RELIC_REGION":                  cfg.Region,
		"TF_VAR_newrelic_api_key":           cfg.ApiKey,
		"TF_VAR_newrelic_account_id":        cfg.SubAccountId,
		"TF_VAR_newrelic_parent_account_id": cfg.ParentAccountId,
		"TF_VAR_subaccount_name":            cfg.SubaccountName,
		"TF_VAR_admin_group_name":           cfg.AdminGroupName,
		"TF_VAR_readonly_user_email":        cfg.ReadonlyUserEmail,
		"TF_VAR_readonly_user_name":         cfg.ReadonlyUserName,
		"BROWSER_LICENSE_KEY":               cfg.BrowserLicenseKey,
		"BROWSER_APPLICATION_ID":            cfg.BrowserAppID,
		"BROWSER_ACCOUNT_ID":                cfg.BrowserAccountID,
		"BROWSER_TRUST_KEY":                 cfg.BrowserTrustKey,
		"BROWSER_AGENT_ID":                  cfg.BrowserAgentID,
	}

	var lines []string
	for k, v := range envMap {
		if v != "" {
			lines = append(lines, fmt.Sprintf("%s=%s", k, v))
		}
	}

	os.WriteFile(".env", []byte(strings.Join(lines, "\n")+"\n"), 0644)
	fmt.Println("\n>>> Configuration updated in .env")
}
