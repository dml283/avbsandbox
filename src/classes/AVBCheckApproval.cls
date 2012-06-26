public class AVBCheckApproval
{
    private static boolean approvalset = false;
    public static boolean SubmittedApproval() 
    {
        return approvalset;
    }
    public static void setapprovalset() 
    {
        approvalset = true;
    }
    public static void setapprovalfalse()
    {
    	approvalset = false;
    }
}