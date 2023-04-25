# Querying Incident Data

**Table of Contents:**

   - [Querying Incidents](#querying-incidents)
      - [Building the Query](#building-the-query)

## Querying Incidents

Occasionally we will need a do a search for incidents that match a certain query. We will use a couple of other operations to complete this, but the helper function we will be using to complete the search is the findIncidents function.

>helper.findIncidents()

As mentioned before, we will need to use a few other Operations that are important to building the query, so let's touch on those before showing how to use the helper operation.

### Building the Query

The 2 operations that we will be using to build the query are the fields and query_builder operations. These will then be used to build a filter, turn that filter into a query, and finally using the helper operation, use that query to find any incidents that match the filter.

First let's look at the query_builder operation. This is a fairly simple operator that allows you to build very complex filters for your query. You build the filter by building using 1 or more comparators. The available comparators are below:

>contains
>
>equals
>
>hasNoValue
>
>hasValue
>
>isGreaterThan
>
>isGreaterThanOrEquals
>
>isLessThan
>
>isLessThanOrEquals
>
>notContains
>
>notEquals

Once you have filter built, you will build the query by using the `build` function within the operation.

For official documentation on the Query Builder operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-query-builder-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-query-builder-operations)

With the understanding of how the query builder works, we will use the field operation to help establish the filter. This operation is similar to the incident operation which allows you to access all of the fields of an incident. The difference is that with an incident you are accessing a specific incidents fields and their values. With fields, we will be accessing all of the fields available within incidents, but with no values. In `query_builder` we use the comparators to define the fields we are building a filter for along with the values we are searching for within that field. The example below shows how that can work.

>query_builder.contains(fields.incident.field_name, 'value')

While there isn't much to it, the official documentation on the Fields operator, check out the KB article found here: [https://www.ibm.com/docs/en/sqsp/48?topic=scripts-fields-operations](https://www.ibm.com/docs/en/sqsp/48?topic=scripts-fields-operations)

Now let's put all of this information together in one final script. We can use this functionality to search for incidents for many reasons. In the email parsing script, we use this to search for an incident to associate the email with, but we can do this to pull field information from other incidents. In the sample script below, we will demonstrate how to view all active incidents in a Python list.

```py
query_builder.equals(fields.incident.plan_status, 'A')
query = query_builder.build()

incidents = helper.findIncidents(query)
```
