# Parsing Emails from the Inbox

**Table of Contents:**

   - [Email Message Analysis](#email-message-analysis)
      - [Header Analysis](#header-analysis)
         - [Email Members](#email-members)
            - [Sender](#sender)
            - [Recipients](#recipients)
         - [Important Date/Times](#important-datetimes)
         - [Email Content](#email-content)
            - [Email Subject](#email-subject)
            - [Body of the Email](#body-of-the-email)
            - [Attachment Analyzing](#attachment-analyzing)
   - [Incident Association](#incident-association)
      - [Associate with Existing Incident](#associate-with-existing-incident)
      - [Create New Incident for Email Association](#create-new-incident-for-email-association)

## Email Message Analysis

Email Message is a class within SOAR that will be used to pull information from emails in the inbox when using the Email Message object type. This information includes the header information such as who the email was sent to, who it is from, the subject, and date/times for sending and receiving as well as the message body and any attachments.

**It is also important to note that as of the writing of this doc, the email messages are not supported outside of the rules and scripts old method of automation, so we will be working in the customizations page and not using playbooks.**

For official documentation on the Email Message operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-email-message-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-email-message-operations)

### Header Analysis

When analyzing the header of an email in the inbox use the following operations in the Email Message class while using email message object type in a script.

>emailmessage.headers

>emailmessage.sender
>
>emailmessage.to
>
>emailmessage.cc

>emailmessage.sent_date
>
>emailmessage.received_date

The headers operation of emailmessage is how the entire headers of the email will be accessed. However, to use the pre-parsed header information like participants in the message, date/times, or subject the other operations will be used.

#### Email Members

The members of the email are pre-parsed and have their own operations. The operations that are used to identify these members within the SOAR scripts will pull the parsed email addresses and names for the from and recipients at the to and cc level. It is also important to note that below is what will be used in Python 3 scripts, but Python2 scripts will use **emailmessage.from** instead of sender.

>emailmessage.sender
>
>emailmessage.to
>
>emailmessage.cc

To understand how to use these better, we will start by looking at the 2 types of variables here.

##### **Sender**
The email sender will only ever be 1 member. Because of that this member will be looked as a dictionary containing 2 points of data. Most of the time when receiving an email from someone you will see a format similar to the one below to show not only the users name, but also the email address. Within SOAR these are both parsed out for us and just need to be called through different operations.

```
John Doe <John.Doe@company.com>
```

First is the `Name` of the user which will be collected using the following operation:

>emailmessage.sender.name

Second is the `Email Address` of the user which can be collected using the following operation:

>emailmessage.sender.address

##### **Recipients**

The recipients of the email are broken down into 2 categories, TO and CC. As you well know, the amount of users that can be in either of these variables can be endless; therefore, we handle these like they are lists no matter if it is 1 user in them or many. This list then contains a list of dictionaries allowing us to handle each user like the sender we stated above. To process the entire list we would do something like the code below shows (obviously doing what you want with each users name and/or email address).

```py
for user in emailmessage.to + emailmessage.cc:
   users_name = user.name
   users_email = user.address
```

#### **Important Date/Times**

The 2 date/times that are preparsed out for you are when the email was originally sent and when it was delivered to the inbox of the system. To get either of these variables, we will used the operations below:

>emailmessage.sent_date
>
>emailmessage.received_date

These are fairly straightforward as they can be directly put into date/time fields within SOAR. The system will set the time to match whatever timezone you have your system displaying as. However, you may need to convert this to a human readable time to post the time in a text field or note. That is where the sample script below comes into play.

```py
from datetime import datetime

def milliepoch_to_readable(unix):
    return(datetime.fromtimestamp(int(unix / 1000)).strftime('%m/%d/%Y %H:%M:%S'))

date_sent = milliepoch_to_readable(emailmessage.sent_date)
date_received = milliepoch_to_readable(emailmessage.received_date)
```

----

Taking this one step further, we can rebuild the header to a standard readable email format using the sample script below by combining the examples above. This will create a note of who the email was sent from and to in HTML formatting.

```py
from datetime import datetime

def milliepoch_to_readable(unix):
    return(datetime.fromtimestamp(int(unix / 1000)).strftime('%m/%d/%Y %H:%M:%S'))


sender = "{} <{}>".format(emailmessage.sender.name,emailmessage.sender.address)
date_sent = milliepoch_to_readable(emailmessage.sent_date)
to_list = []
for user in emailmessage.to:
  to_list.append("{} <{}>".format(user.name,user.address))
cc_list = []
  for user in emailmessage.cc:
    cc_list.append("{} <{}>".format(user.name,user.address))

note = "<b>From:</b> {}\n<b>Sent:</b> {}\n<b>To:</b> {}\n<b>CC:</b> {}".format(sender,date_sent,"\n".join(to_list),"\n".join(cc_list))

incident.addNote(helper.createRichText(note))
```

### Email Content

After going through the header details, we get to the data or content of the email which includes the Subject of the message, the Body of the message, and any attachments details. Similar to the headers we have the ability to look at all of the message body by checking the getBodyHtmlRaw() operation, but more than likely we want to address the parsed info operations like what is listed below.

>emailmessage.getBodyHtmlRaw()

>emailmessage.subject
>
>emailmessage.body
>
>emailmessage.attachments

#### Email Subject

First we will take a look at the email subject. This one is fairly simple as well where we will pull the email subject in a simple text format the way it comes in. Subject don't contain any formatting so there is no special things to do here.

>emailmessage.subject

#### Body of the email

The next section we will parse out is the body of the email. The body is parsed out already for us in a dictionary model. The structure of that dictionary is the format and content. The format options are either `html` or `text`. We can then grab the data or content using the operation below.

>emailmessage.body.content

We can then use the code below to take that code and add it as a note to an incident similar to how we rebuilt the headers above.

```py
message = emailmessage.body.content
incident.addNote(helper.createRichText(message))
```

#### Attachment Analyzing

Attachments are not directly interactable from the Python script. In order to access them you will need to open the email that gets attached to the incident after the email is associated with a incident. Then you can download the attachments within.

However, we can perform analysis on these attachments. The system will parse out specific information and give us some information on them. That is done through the attachments operation.

>emailmessage.attachments

Similar to how we handled recipients, attachments are in a list format. So we will need a `for` loop to parse through all of the analyzed data for each attachment. Once we get to the attachment itself, it is in dictionary format. Some of the important parsed data is listed below:

>filename
>
>content_type
>
>size
>
>inline

For the first 2, filename and content_type, there are 2 prefixes that go along with those. First is the `"presented_"` prefix which displays what the file claims to be. Alternatively the `"suggested_"` prefix which displays what the system has identified the attachment as. This means that you can run a comparison on what the file says it is vs what the file actually appears to be. The last thing to mention is the inline operation. That operation allows for the determination of if the file was added as a standard attachment, `False`, or if it was added into the body of the message, `True`. Below is a sample script of doing a comparison on each attachment and adding a note of determination.

```py
for attachment in emailmessage.attachments:
   same_filename = True
   same_content_type = True
   if attachment.presented_filename != attachment.suggested_filename:
      same_filename = False
   if attachment.presented_content_type != attachment.suggested_content_type:
      same_content_type = False
   
   note = "Attachment Name: <b>{}</b>\n\nIs the filenames the same? {}\nIs the content type the same? {}".format(attachment.presented_filename,same_filename,same_content_type)

   incident.addNote(helper.createRichText(note))
```

## Incident Association

Now that we know how to parse out all of the information of the email message details, we have to build the association to an incident. This will allows the script to know which incident were are attempting to do something with when we use operations such as assign values to fields using `incident.field`, create a new notes using `incident.addNote`, or any of the other incident operations. We can do this 1 of 2 ways.

1. Find an existing incident to associate with or/
2. Create a new incident completely

### Associate with Existing Incident

While this first method can be quite complicated when performing searches across incidents and associating the message to an incident once found, this allows for the platform to be extremely powerful to communicate with people outside the platform as well as associate lots of different emails all together that might otherwise not be associated easily. The way we do this is by using several operations, but the main operation we will be talking about today is listed below:

>emailmessage.associateWithIncident()

As stated before this can get very complicated as we build out a incident search query to find our perfect incident, but to make this a little more simple I will discuss how I have handled this in the past with messages that left the system and got a response back. When I would send an email out, I appended the Incident ID to the end of the subject. This would allow me to easily parse that ID out and associate the correct incident quickly. The format for that would be `"Some kind of subject" + (ID: 1234)`. I would then just look for the ID by doing a regex and build the association. The script below shows how to do that as we have to first parse the ID out, then build the query, then run the query, and finally pass the results the the associateWithIncident operation.

To perform the search to associate the email with an incident follow the instructions on the [Querying Incident Data](../Querying%20Incident%20Data/) page.

You will then choose one of the resulting incidents to pass to the `associateWithIncident()` function. The sample script below puts all of this together.

```py
import re

regex = re.compile(r'\(ID: (\d+)\)')
incident_id = re.findall(regex,emailmessage.subject)

if incident_id:
   query_builder.equals(fields.incident.id, incident_id[0])
   query = query_builder.build()

   incident = helper.findIncidents(query)[0]

   emailmessage.associateWithIncident(incident)
```

### Create New Incident for Email Association

This is of course the simplest way to handle these, however, may not be the best way as this means each email creates another incident and likely won't be able to update an incident that the email may be about. If we have completed a search though like the instructions above state and we are unable to find an incident to associate with, then we will just need to create a new incident as this may be a completely new communication. For this we will use the operation below:

>emailmessage.createAssociatedIncident()

For this operation, the function requires 2 inputs. First is the incident name. This could be the subject of the email or something else that we make up. The second is the owner of the new incident. We can use either a system user's email address or a group name. Below is a sample script of how we can create that new incident.

```py
subject = emailmessage.subject

emailmessage.createAssociatedIncident(subject,"John_Doe@company.com")
```

----

Now let's combine both of these to create a combined script so that we can build the association by first checking if the incident should be associated with an existing incident and if not create a new incident.

```py
import re

regex = re.compile(r'\(ID: (\d+)\)')
incident_id = re.findall(regex,emailmessage.subject)

if incident_id:
   query_builder.equals(fields.incident.id, incident_id[0])
   query = query_builder.build()

   incident = helper.findIncidents(query)[0]

   emailmessage.associateWithIncident(incident)
else:
   subject = emailmessage.subject
   emailmessage.createAssociatedIncident(subject,"John_Doe@company.com")
```
