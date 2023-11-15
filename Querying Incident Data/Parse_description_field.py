# The following script will take in the description of the case and parse through it. Yu can then assign the values to artifacts or case fields. 

# Example description field 
# As of the time of this writing, the Proofpoint TAP integration puts all of the details in the description. 

##TAP Event Kind: messagesDelivered
##Classification: phish
##Sender: bounces+229012-6816-jon.stewart=example.com@email.badurl.com
##Subject: Examplecompany-Payment/Receipt
##From address: ['support@badurl.com']
#From header: PaymentGateway <support@badurl.com>
#Header Reply To: None
#Header To: N/A
##Recipient: ['jon.stewart@example.com']
##Sender IP: 1.1.1.1
##Click IP: N/A
##Threat URL: N/A
#Message ID: <73b4f1fd-a542-be6a-a4c1-5f0660abcdea@badurl.com>

# Import Regex package (optional)
# If the description field does not contain HTML formatting, then the regex is not neeeded.
import re

# Pull in Incident Description content
description = incident.description.content

# Use regex to strip description of HTML tags
plain_body = re.compile(r'(<([^>]+)>)', re.IGNORECASE | re.MULTILINE ).sub("\n", description).strip()

# Split description on character returns (\n) and return a list
split_desc = description.split('\n')

# Iterate over list and create dictionary
dictionary = {}
for i in range(0,len(split_desc)):
  line = split_desc[i]
  keyvpair = line.split(':')
  if keyvpair[0] in dictionary.keys():
    dictionary["duplicate-"+keyvpair[0].strip(" ")] = keyvpair[1].strip(" ")
  else:
    dictionary[keyvpair[0].strip(" ")] = keyvpair[1].strip(" ")

# Iterate over dictionary and create artifact or assign to custom property
for key in dictionary:
  # Skip entry if the value is N/A 
  if "N/A" in dictionary[key]:
    continue
  if "Sender IP" in key:
    incident.addArtifact("IP Address", dictionary[key], "IOC from Proofpoint")
  elif "From address" in key:
    incident.addArtifact("Email Sender", dictionary[key].strip("[' ']"), "IOC from Proofpoint")
  elif "TAP Event Kind" in key:
    incident.properties.proofpoint_tap_event_kind = dictionary[key]
  elif "Classification" in key: 
    incident.properties.proofpoint_classification = dictionary[key]
  elif "Sender" in key:
    incident.addArtifact("Email Sender Name", dictionary[key], "IOC from Proofpoint")
  elif "Subject" in key: 
    incident.addArtifact("Email Subject", dictionary[key], "IOC from Proofpoint")
  elif "Click IP" in key:
    incident.addArtifact("IP Address", dictionary[key], "IOC from Proofpoint")
  elif "Recipient" in key:
    incident.addArtifact("Email Recipient", dictionary[key].strip("[' ']"), "IOC from Proofpoint")
  elif "Threat URL" in key: 
    incident.addArtifact("URL", dictionary[key], "IOC from Proofpoint")

