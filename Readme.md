How this works

Step 1 – Token
Uses Invoke-RestMethod to call the OAuth2 token endpoint, getting a Bearer token for Microsoft Graph.

Step 2 – Loop through users
Calls https://graph.microsoft.com/v1.0/users with $select to limit attributes.
If the result has a @odata.nextLink, it updates $graphUrl and keeps looping → this is how it walks through the entire “directory”.

Step 3 – Backup

Writes raw JSON → good for restore or replay into other tools.

Writes flattened CSV → good for analysis, Excel, reporting.