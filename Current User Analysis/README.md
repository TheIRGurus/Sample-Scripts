# Analyzing the Current User

**Table of Contents:**

   - [Principal Analysis](#principal-analysis)
      - [Type of User](#type-of-user)
      - [User's Email](#users-email)
      - [User's Name](#users-name)
   - [Groups](#groups)
      - [User Group Lookups](#user-group-lookups)

## Principal Analysis

Principal is a class within SOAR that will allow you to pull information from the user that kicked off an automation. This information includes the type of user, the user's name, and finally the users email address for identifying the account.

For official documentation on the principal operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-principal-operations](https://www.ibm.com/docs/en/sqsp/46?topic=scripts-principal-operations)

### Type of User

When there is a need to identify the type of user, we use the following operator from the principal class.

>principal.type

This will pull the type of account that kicked off the automation being run. The types of User Accounts we expect to see are:

   - user
   - group
   - apikey

Some of the ways we may use this in scripting is for doing something based on if this was completed automatically or by a user. Below is a script that was used to assign an Task to a user on close, if it was an actual person.

```py
if str(principal.type) == "user":
  task.owner_id = principal.id
```

### User's Email

The method that we identify users within the SOAR platform is by their email. Using the following name operator from the principal class allows us to identify the user performing the automation.

>principal.name

The sample script below uses the operator to assign the user as the owner of an incident. The incident owner can be assigned to either a user or a group.

```py
incident.owner_id = principal.name
```

### User's Name

The user's full name can be used to post comments to an incident or identify who was sending an automated email from the system. However, instead of allowing the user to fill this information in themselves, the system allows us to pull the current users display name from the system using the below operator from the principal class.

>principal.display_name

The following script shows the system providing the user's full name in a script where we are sending a standard email template with the Analysts name who issued the email.

```py
email_body = """To Whom is May Concern:
This email is to inform you that your account has been blocked from sending outbound emails.

Thanks!
{}
""".format(principal.display_name)
```

## Groups

Groups is a class within SOAR meant to give scripts the ability to tell if a user is in a specific group. Ultimately when the lookup is true, it give responds with the principal of the group specified.

For official documentation on the groups operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-groups-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-groups-operations)

### User Group Lookups

Groups only has 1 operator. The operator below is used for checking to see if the user who ran an automation is in a specified group.

>groups.findByName('Group Name')

With the ability to lookup if the user is in a specific group you can do things like cause automations to fail if they are not in a group. The way this works is by checking the results of the code above. If the command returns results, the results are the principal information of the group which means that the user is in that group. If the results are a None type, then the user is not in the group. The script below demonstrates how this could work with the use of a helper function throwing an error when the user is not in a group.

```py
if groups.findByName('Group Name'):
    pass
else:
    helper.fail('The user, {}, is not authorized to run this automation.'.format(principal.display_name))
```
