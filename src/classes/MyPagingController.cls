public with sharing class MyPagingController {

    //Sorting
    private String sortDirection = 'ASC';
    private String sortExp = 'CaseNumber';


private List<Case> cases;

private List<Case> pageCases;

private Integer pageNumber;

private Integer pageSize;

private Integer totalPageNumber;

public Integer getPageNumber()
{

return pageNumber; 

}

public String sortField {get; set;}

public String previousSortField {get; set;}


public List<Case> getCases()

{

return pageCases;

}


public Integer getPageSize()

{

return pageSize;

}


public Boolean getPreviousButtonEnabled()

{

return !(pageNumber > 1);

}


public Boolean getNextButtonDisabled()

{

if (cases == null) return true;

else

return ((pageNumber * pageSize) >= cases.size());

}


public Integer getTotalPageNumber()

{

if (totalPageNumber == 0 && cases !=null)

{

totalPageNumber = cases.size() / pageSize;

Integer mod = cases.size() - (totalPageNumber * pageSize);

if (mod > 0)

totalPageNumber++;

}


return totalPageNumber;

}


public MyPagingController()

{

pageNumber = 0;

totalPageNumber = 0;

pageSize = 5;

ViewData();

}


public PageReference ViewData()

{ 

cases = null;

totalPageNumber = 0;

BindData(1);

return null;

}


private void BindData(Integer newPageIndex)

{

try

{


if (cases == null)

cases = [select CaseNumber, Account.Name, Account.Account_ID__c, Status,Reason, Case_Primary_Type__c, Owner.Alias, AVB_Contact_Name__c from Case where IsClosed= false and Owner.ProfileId =  '00e60000000r2eO' order by CaseNumber];



pageCases = new List<Case>();


Transient Integer counter = 0;

Transient Integer min = 0;

Transient Integer max = 0;


if (newPageIndex > pageNumber)

{

min = pageNumber * pageSize;

max = newPageIndex * pageSize;

}

else

{

max = newPageIndex * pageSize;

min = max - pageSize;


}



for(Case c : cases)

{

counter++;

if (counter > min && counter <= max) 

pageCases.add(c);

}


pageNumber = newPageIndex;


if (pageCases == null || pageCases.size() <= 0)

ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO,'Data not available for this view.'));

}

catch(Exception ex)

{

ApexPages.addmessage(new ApexPages.message(ApexPages.severity.FATAL,ex.getMessage()));

}


}


public PageReference nextBtnClick() {


BindData(pageNumber + 1);

return null;

}


public PageReference previousBtnClick() {


BindData(pageNumber - 1);

return null;

}

public void doSort(){
    String order = 'asc';
    
    /*This checks to see if the same header was clicked two times in a row, if so, it switches the order.*/
    if(previousSortField == sortField) {
        order = 'desc';
        previousSortField = null;
        }
        else {
            previousSortField = sortField;
            }
            
        //To sort the table we simply need to use this one line, nice!
        superSort.sortList(cases,sortField,order);
        }

    
}