If there is a DocuSign task for the same contact and same DocuSign template that is in draft status, show a message to the user and ask for a response before continuing forward.  "There is already a DocuSign task in draft status for the same contact and template.  Are you sure you want to continue with creating a new DocuSign task?"



- Task = Docusign

- Click Create Draft in task, it pops docusign window, select contact and authentication option, click Create Draft again, at that point you would check for any open tasks that are Docusign, with the same selected docusign template and contact (CDocuSign Envelope Recipient) where Envelope status = 'Created'.  If one or more exist pop yes no dialog box with above message.  If no, cancel create draft, if yes let the code continue.


If there is a DocuSign task that has an Envelope status that is not "Completed", and that has not already been voided, show a message to the user and ask for a response before continuing forward.  "There is already a DocuSign task in progress for this contact and template.  You should void the open DocuSign task before sending a new request.  Are you sure you want to continue with a new DocuSign task?"

- Task = Docusign

- Click Create Draft in task, it pops docusign window, select contact and authentication option, click Create Draft again, at that point you would check for any CLOSED tasks that are Docusign, where the Task.Status != 'Cancelled', with the same selected docusign template and contact (CDocuSign Envelope Recipient) where Envelope status != 'Completed'.  If one or more exist pop yes no dialog box with above message.  If no, cancel create draft, if yes let the code continue.



Allow the user to choose to continue past the warning message and create the new DocuSign task.

Allow the user to stop at the warning message and cancel creation of a new DocuSign task.




Tasks for tomorrow:
1) Docusign completion
2) Case bug fix 
