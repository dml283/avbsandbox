trigger exposeTaskActivityDate on Task (before insert, before update) 
{
    Task[] tasks = trigger.new;
    
    for (integer i = 0; i < tasks.size(); i++)
    {
        Task task = tasks[i];
        task.ActivityDueDate__c = task.ActivityDate;
    }
}