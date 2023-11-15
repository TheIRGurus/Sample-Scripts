# This script will take in the name of a case and parse it out. 
# Some integrations may auto create cases and put details in the name 

# Example case name
## Proofpoint TAP Event: https://sp.evilurl.com/index.html?label=planandbook;auth_success=1;aid=1191 malware

# Pull in Incident/case name content
inc_name = incident.name

# Split name on space
split_name = inc_name.split(' ')

# Get index of last two fields from name. 
# In this example, the type is the last field and URL is second to last
case_type_index = len(split_name)-1
url_index = len(split_name)-2

# Take the type and set incident type of case
if "malware" in split_name[case_type_index]:
    incident.incident_type_ids = "Malware"
elif "phish" in split_name[case_type_index]:
    incident.incident_type_ids = "Phishing"

# Using the url from the name, add URL to artifacts of case
incident.addArtifact("URL", split_name[url_index], "IOC from Proofpoint")
