/*
Description: Custom trigger on the OOB Asset object. Invokes Handler.
*/
trigger CA2_AssetTrigger on Asset (after insert, after update, before update, before insert, before delete, after delete, after undelete) {
	new CA2_AssetTriggerHandler().run();
}