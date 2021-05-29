-- Some of this script modified from https://stackoverflow.com/questions/6121917/automatic-rollback-if-commit-transaction-is-not-reached

delimiter //
create procedure migration()
begin 
   DECLARE exit handler for sqlexception
      BEGIN
      
      GET DIAGNOSTICS CONDITION 1 @p1 = RETURNED_SQLSTATE, @p2 = MESSAGE_TEXT;
	  SELECT @p1, @p2, "ERROR999";
     
      ROLLBACK;
   END;

   DECLARE exit handler for sqlwarning
     BEGIN
      GET DIAGNOSTICS CONDITION 1 @p1 = RETURNED_SQLSTATE, @p2 = MESSAGE_TEXT;
	  SELECT @p1, @p2, "ERROR999";
	  
     ROLLBACK;
   END;
   
   START TRANSACTION;

UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '0D8A572F-923B-485F-B115-FFF5B8E9BF2E';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '1F54F6ED-FD5A-4096-BD45-76F22E540F91';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'A03002DA-3CE0-48F1-80EF-42C9B913543E';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '149E44C6-47AD-4A7E-8574-39FEB032CBBB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '40154E39-5DC1-4EA1-B03D-88B3136C3378';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'D6171C17-FDBE-4896-9257-0FD86A0ED952';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '88CB281F-7A0F-41B9-A982-E3E6406B83EB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'D6FD75B1-2B31-4F57-BFAA-E627766E24B0';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '21C1BA10-76B7-4F2C-9402-F5541762B5BD';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '768064D9-40F4-4DC9-B2E9-E01B8916F55D';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = 'D6076AD0-B8D7-4E80-9990-97205C91C804';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '12BD101B-1F1C-43B4-A0CF-8B897B984C1D';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = 'E522DACA-B5E4-4E07-92F6-780356C350EA';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = 'FDF2BFC2-61ED-4F0F-821E-5A9FD77450A2';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '10ADE51C-8F9D-44DB-AF89-533311FBB33D';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '196631A3-507B-4C02-A489-BB76AB47B9EB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '77BCE672-19B8-45E3-9CC1-60C5E284AA38';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'A7316A40-3092-4BF2-B5B3-350B0BA490CD';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = 'D9AFC645-5800-41C3-B60C-04D012BE010F';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = 'FC27D5D6-F8D3-4120-93B3-985F1155BD7A';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '297FB4BA-3319-4C03-BA94-62A2CDC5F603';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '53F0D9A8-01AF-4F5D-BC76-A4CEF625413F';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '7AC351FA-AABB-4FC0-9D90-C741E3D7DD23';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '619C58E1-F7B2-4D24-9AC9-215F58A085CB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = 'E3370D6A-1E88-497D-B350-DC0D1C5095FF';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'E6554024-5920-4EB5-8A0C-6D29754CAF1D';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '039BCB72-6DDE-4CA7-983A-CDF61F4430ED';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '1D86BCEA-46D0-449E-9216-839D2FC21BEB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = 'E40B1028-F703-40E0-B64A-62EE423C52C2';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '291012D9-D17B-4AB3-B3A6-9FE3A07A4CF5';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '96EA49CD-6C8C-4B71-98E2-97DCC9D9DD16';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = 'EF4CEABD-2039-4D70-846D-8D230A158B3B';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '0D0C381E-6CA1-487B-B97B-D400F59F8FF2';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '87ED4300-367F-4516-B666-75531C0F6C83';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'C62F8995-6B82-410B-9EE6-788C6BE5AE05';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '4C30E02E-EA39-41B3-8C66-45F5CE9598BB';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = '7C82DB37-8097-4E85-8E3E-1ADEE3450441';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '82B97CC0-BF94-4E38-ABC1-7C5E6BE20FD5';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '19A3F45D-0D74-406C-9D45-707CB2C585D3';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '3664A2B5-FE84-49D8-90C7-EFA063DE2FE1';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'C87AABC2-AF16-4445-AEA1-0A110077A08E';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'image' WHERE fileUUID = '174EB62D-7001-4EAC-ABB5-8FBC5042AC58';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE fileUUID = '9A77983B-A679-424F-8144-96D9E8059B4E';
UPDATE FileIndex SET objectType = 'url', fileLabel = 'url' WHERE fileUUID = 'C46E6D9F-74D3-415E-922E-823EDE208D73';
		
		SELECT "SUCCESS123";
		
   COMMIT;
   
end//
delimiter ;

-- Not needed because the command line invocation of mysql specifies the database.
-- Use SyncServer_SharedImages;

call migration();
drop procedure migration;

