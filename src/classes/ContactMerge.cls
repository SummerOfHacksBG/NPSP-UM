/*
    Copyright (c) 2009, Salesforce.com Foundation
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.com Foundation
* @date 2011 (2.x)
* @description Handles the heavy lifting of merging contacts. Called from VF merge page 
*/
public class ContactMerge {

	//This class handles the heavy lifting of merging contacts. It can be called
	//from the VisualForce page for contact merge, or elsewhere.
	
	//min number of contacts that can be merged
	public final Integer MERGE_MINIMUM = 2;
	
	//max number of contacts that can be merged
	public final Integer MERGE_LIMIT = 3;
    
    //contact for the winning record
    public Contact winner {get; set;}
    
    //List for the losing records
    public List<Contact> losers {get; set;}
        
		
	//method to merge the winner and losers
	public boolean mergeContacts() {
		boolean successfulMerge = false;
		
		List<Account> winnerAccount = new List<Account>();
		Set<Id> loserAccountIds = new Set<Id>();
		List<Account> loserAccounts = new List<Account>();
		List<Account> loserAccountsToBeMerged = new List<Account>();
		List<Account> loserAccountsToBeDeleted = new List<Account>();
	
		Id winningAccountId = null;
		Boolean winnerAccountIsOneToOne = false;
		winner = [Select Account.Id,Account.SYSTEM_AccountType__c from Contact where Id=:winner.Id];
		//get winner contact Account
		if (winner.AccountId!=null){
			winnerAccount = [Select Id,SYSTEM_AccountType__c,Name from Account where Id=:winner.accountid];
		}
			
		if (winnerAccount.size()>0) {
			
			winningAccountId = winnerAccount[0].Id;
			
			if(winnerAccount[0].SYSTEM_AccountType__c==Constants.ONE_TO_ONE_ORGANIZATION_TYPE){
				winnerAccountIsOneToOne = true;
			}
			
		}	
		losers = [Select Account.Id,Account.SYSTEM_AccountType__c from Contact where Id IN :losers];
		
		for(Contact thisloserContact : losers){
			//don't try to merge null Accounts or Accounts that are the same as the winner's Account
			if (thisloserContact.id!=null && thisloserContact.AccountId!=winner.AccountId){
				loserAccountIds.add(thisloserContact.AccountId);
			}
		}
		system.debug('losers: ' + loserAccountIds);
		system.debug('winneraccountid: ' + winner.AccountId);
		//get loser contact Accounts that should be merged out--only one-to-one accounts
		loserAccountsToBeMerged = [Select Id,SYSTEMIsIndividual__c,SYSTEM_AccountType__c,Name from Account where Id IN :loserAccountIds and SYSTEM_AccountType__c=:Constants.ONE_TO_ONE_ORGANIZATION_TYPE and Name<>:Constants.BUCKET_ACCOUNT_NAME];
		
		
		//one-to-one contacts each have an Account, so when merging Contacts we have to merge Accounts as well
		//we merge the Accounts first, if there are any one-to-one Accounts in the mix
		if(loserAccountsToBeMerged.size()>0){	
					
			merge winnerAccount[0] loserAccountsToBeMerged;
		}
		
		//merge the contacts
		
		//there is a Contact delete trigger that deletes the one-to-one Account of a Contact after it is deleted
		//merge deletes the losing Contacts, so their Accounts get deleted, which causes errors
		//to get around this, we detach the Contacts for their Accounts before we merge
		
		//create new contacts for updating as the SOSL returned contacts have read-only fields on them
		Contact winnerMakePrivate = new Contact();
		if(winnerAccountIsOneToOne){			
			winnerMakePrivate = new Contact(Id = winner.id,AccountId = null,Private__c=true);
		} else {
			winnerMakePrivate = new Contact(Id = winner.id);
		}
		List<Contact> losersMakePrivate = new List<Contact>();
		
		for(Contact contactForUpdate : losers){			
			Contact loserMakePrivate = new Contact(id=contactForUpdate.id,accountId=null,Private__c=true);
			losersMakePrivate.add(loserMakePrivate);
		}
			
		//set the account to null and mark private so that trigger won't reset the Account
		if (winningAccountId!=null && winnerAccountIsOneToOne){			
			update winnerMakePrivate;			
		}
		
		if(losersMakePrivate.size()>0){
			update losersMakePrivate;
		}

		merge winnerMakePrivate losersMakePrivate;
		
		//set the contact Account Id back to the winning Account Id
		if (winnerAccountIsOneToOne){
			winnerMakePrivate.AccountId = winningAccountId;
			winnerMakePrivate.Private__c = false;
			update winnerMakePrivate;
		}		
		system.debug('loserAccounts: ' + loserAccountsToBeDeleted);
		if(loserAccountsToBeDeleted.size()>0){
			delete loserAccountsToBeDeleted;
		}
		successfulMerge = true;
		return successfulMerge;
	}
		
    //constructor for mergeSet class
    public ContactMerge(Contact winner, List<Contact> losers) {
		this.losers = losers;
		this.winner = winner;
    }        
    
}