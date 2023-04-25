# Script Testing and Logging

**Table of Contents:**

   - [Log Handling in Scripts](#log-handling-in-scripts)
      - [Log Levels](#log-levels)
   - [Using Helper to Enhance SOAR](#using-helper-to-enhance-soar)
      - [Failing Softly](#failing-softly)
      - [Converting Text](#converting-text)

## Log Handling in Scripts

Log is a class within SOAR that is used for creating log messages within a script. This can be used for both testing as well as error handling when trying to build and use scripting within the system. These logs within scripts are also outputted and persistent in the resilient-scripting.log file when the logs are collected on the SOAR System.

For official documentation on the Log operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-log-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-log-operations)

### Log Levels

When writing a script, we often need to understand what is happening if we are facing problems. The way we do that is by creating logs. These logs can be at multiple levels though. 

>log.info()
>
>log.warn()
>
>log.error()
>
>log.debug()

These logs can help verify where we are in a script, giving us more or less detail when checking the debug vs the info logs. You can also supply error logs to softly error our a script and track exactly where the error took place. The script below shows how those logs can be created.

```py
log.debug('Incident ID: {}'.format(incident.id))
try:
   log.info('Attempting to do something.')
   pass
except Exception as e:
   log.error(e)
```

## Using Helper to Enhance SOAR

Helper is a class within SOAR adding multiple features that will provide additional functionality to SOAR. Things like soft failing with an error message, changing texts to fit different fields such as a standard text field or a rich text area, and searching the system for incidents matching a certain filter.

For official documentation on the Helper operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-helper-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-helper-operations)

### Failing Softly

Sometimes we will need to stop a script or playbook from running because of something not being done properly in a task before or the user not being in the right group to run an automation. We do this using the fail function of the helper operation.

>helper.fail()

The helper function will stop the script in its tracks by throwing an error in a pop-up to display to the analyst activating the script by either progressing the playbook or activating the script. Below is the way we will use it within a script.

```py
if incident.properties.custom_variable == "unknown":
   helper.fail('Please update Customer Variable in order to close task.')
```

### Converting Text

When we are dealing with different kinds of text fields, we may need to convert text from plain text to rich text or vice versa so that the text will be properly formatted in a note or rich text area. Below is how we do the conversion.

>helper.createRichText()
>
>helper.createPlainText()

The 2 different conversions will result in either seeing the information without any HTML formatting or seeing it with it formatted in HTML. The way it completes that is by creating a dictionary with the content being the text supplied in the note with the format of either `text` or `html`. The script below shows how this can be used.

```py
note = "<a href={url}>{url}</a>".format(url="https://www.google.com")

incident.addNote(helper.createRichText(note))
```
