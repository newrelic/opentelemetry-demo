# Test Alerts - to be folded into Resources
This is a WIP. 
What's here:
Astronomy Service Metric Health Policy
* Baseline and threshold alerts for checkout, product-catalog, shipping, frontend, ad, cart

Astronomy Service Span Health Policy
* Baseline and threshold alerts for everything else that is captured as a service

Tags (Open to change)
* author
* data-type

Baseline dashboard json
To be used to set thresholds 

Work left
* Detailed threshold alerts? 
* Showcase back to team?
* Fold into resources folder? 
* Use modules to make it easier to manage many alerts?

To test these alerts:
* terraform init - to initialize the directory
* terraform apply -var-file="secret.tfvars" - to see what's going to get created
* terraform plan  -var-file="secret.tfvars" - to apply the new alert policies and alerts

Vars set in secret.tfvars: (yes, only the first value is a secret but I was rushing)
newrelic_api_key = <Your API Key in double quotes>
newrelic_region = "US"
newrelic_account_id = <Your account id in double quotes>
