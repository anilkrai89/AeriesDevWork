@isTest
private class CA2_TriggerHandlerTest {
	
	@isTest static void testHandlerLoopCountMethods() {
		//Can't run meaningful assertions since all getter methods are within the inner class.  These getter methods are validated in later tests
		CA2_TriggerHandler handler = new CA2_TriggerHandler();
		CA2_TriggerHandler.LoopCount loopCount = new CA2_TriggerHandler.LoopCount();
		handler.setMaxLoopCount(10);
		handler.setMaxLoopCount(3);
		handler.clearMaxLoopCount();
	}

	@isTest static void testContextSpecificOverrideMethods(){
		//Nothing to assert
		CA2_TriggerHandler handler = new CA2_TriggerHandler();
		handler.beforeInsert();
		handler.afterInsert();
		handler.beforeUpdate();
		handler.afterUpdate();
		handler.beforeDelete();
		handler.afterDelete();
		handler.afterUndelete();
	}

	@isTest static void testSetTriggerContext(){
		CA2_TriggerHandler handler = new CA2_TriggerHandler();
		handler.setTriggerContext('before insert', true);
		System.assert(handler.context.name() == 'BEFORE_INSERT');
		handler.run();

		handler.setTriggerContext('before update', true);
		System.assert(handler.context.name() == 'BEFORE_UPDATE');
		handler.run();

		handler.setTriggerContext('before delete', true);
		System.assert(handler.context.name() == 'BEFORE_DELETE');
		handler.run();

		handler.setTriggerContext('after insert', true);
		System.assert(handler.context.name() == 'AFTER_INSERT');
		handler.run();

		handler.setTriggerContext('after update', true);
		System.assert(handler.context.name() == 'AFTER_UPDATE');
		handler.run();

		handler.setTriggerContext('after delete', true);
		System.assert(handler.context.name() == 'AFTER_DELETE');
		handler.run();

		handler.setTriggerContext('after undelete', true);
		System.assert(handler.context.name() == 'AFTER_UNDELETE');
		handler.run();
	}

	@isTest static void testLoopCountExceed() {
		CA2_TriggerHandler handler = new CA2_TriggerHandler();
		CA2_TriggerHandler.LoopCount loopCount = new CA2_TriggerHandler.LoopCount();
		handler.setMaxLoopCount(1);
		handler.addToLoopCount();

		Boolean except = false;
		try{
			handler.addToLoopCount();
		}catch(Exception e){
			except = true;
		}
		System.assert(except == true);
	}

	@isTest static void testValidateRun() {
		CA2_TriggerHandler handler = new CA2_TriggerHandler();

		Boolean except = false;
		try{
			handler.validateRun();
		}catch(Exception e){
			except = true;
		}
		System.assert(except == true);

		CA2_TriggerHandler.bypass(handler.getHandlerName());
		handler.setTriggerContext('before insert', true);
		Boolean except2 = false;
		try{
			System.debug(handler);
			handler.validateRun();
		}catch(Exception e){
			except2 = true;
		}
		System.assert(except2 == false);

	}

	@isTest static void testLoopInnerMethods() {
		CA2_TriggerHandler.LoopCount loopCount = new CA2_TriggerHandler.LoopCount(10);
		System.assert(loopCount.getMax() == 10);
		System.assert(loopCount.getCount() == 0);

		loopCount.setMax(3);
		System.assert(loopCount.getMax() == 3);
	}

	@isTest static void testBypass() {
		CA2_TriggerHandler.bypass('Test');
		//System.assert(CA2_TriggerHandler.bypassedHandlers.contains('Test'));
	}

	@isTest static void clearBypass() {
		CA2_TriggerHandler.bypass('Test');
		CA2_TriggerHandler.clearBypass('Test');
		//System.assert(!CA2_TriggerHandler.bypassedHandlers.contains('Test'));
	}

	@isTest static void isBypassed() {
		CA2_TriggerHandler.bypass('Test');
		System.assert(CA2_TriggerHandler.isBypassed('Test'));
	}

	@isTest static void clearAllBypasses() {
		CA2_TriggerHandler.bypass('Test');
		CA2_TriggerHandler.bypass('Test2');
		CA2_TriggerHandler.clearAllBypasses();
		//System.assert(CA2_TriggerHandler.bypassedHandlers.size() == 0);
	}
	
}