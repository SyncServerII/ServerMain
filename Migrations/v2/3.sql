
-- Some of this script modified from https://stackoverflow.com/questions/6121917/automatic-rollback-if-commit-transaction-is-not-reached

-- This assumes that the URL object type has already been processed

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

UPDATE FileIndex SET objectType = 'image', fileLabel = 'image' WHERE objectType is NULL and mimeType = 'image/jpeg';
UPDATE FileIndex SET objectType = 'image', fileLabel = 'comments', changeResolverName = 'CommentFile' WHERE objectType is NULL and mimeType = 'text/plain';
		
		SELECT "SUCCESS123";
		
   COMMIT;
   
end//
delimiter ;

-- Not needed because the command line invocation of mysql specifies the database.
-- Use SyncServer_SharedImages;

call migration();
drop procedure migration;

