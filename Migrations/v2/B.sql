
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

INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('15BB1FAE-D5E5-4694-AE36-04D003802E18', 'ðŸ— chicken is the question', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('2BC25814-FED5-441E-9B6D-3355E6BE367E', 'ðŸŽ¥ ðŸ¿ ðŸŽ­ movies and TV are the ticket', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('5559BB4F-F232-4633-8C55-A031DFF5FCFE', 'ðŸŽµ ðŸŽ¸ ðŸ¥ ðŸŽ¶', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('60A52DB4-39A8-486A-976C-A1DE0C922919', 'ðŸŽ²â™¦ï¸ â™ ï¸ â¤ï¸â™£ï¸ðŸŽ²', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('67BFA324-5FD5-4547-844E-BE1616A71C64', 'Bookes ðŸ“š ðŸ“–', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('8A02F515-616A-421C-B797-2C72A7F23C63', 'How to makum Foodes ðŸŒ®ðŸ¦„', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('9E3884E1-BF93-4588-BDE8-E0DAF3B1D567', 'ðŸ‘©â€ðŸ’»ðŸ‘¨â€ðŸ’»ðŸ§‘â€ðŸ’»', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('AC71AF5A-17C8-4E4D-B8D7-961892CDC1B0', 'Miss Universe ðŸ‘¸ðŸ‘¸ðŸ»ðŸ‘¸ðŸ¼ðŸ‘¸ðŸ½ðŸ‘¸ðŸ¾ðŸ‘¸ðŸ¿', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('B0D8A2A1-F476-4032-93CF-DED70D27CE3A', 'Interviewing', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('E8355EE7-B55C-4D03-B6E0-27EADD760CDF', 'â­•ï¸to be Dany or not to be', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('ED194370-4AC4-4A19-A7D9-10F2481CCC77', 'ðŸ˜† ðŸ˜‚ ðŸ˜› ðŸ¤£ ðŸ¤ª ðŸ˜¹ ðŸ˜­', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('EF8B6DB2-9469-4F0B-BB53-B12C14735BA5', 'Louisiana Guys', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('F03972D9-1DB7-4CA9-8037-2225180093FD', 'ðŸ˜¸ðŸ… ðŸˆ ðŸ± ðŸˆâ€â¬› ðŸ¦ðŸ† God said let there be cats, and they were good', '0');
INSERT INTO SharingGroup (sharingGroupUUID, sharingGroupName, deleted) VALUES ('F7D59832-A829-4A2C-B464-394D5ED00485', 'ðŸ¦µ â­ï¸ ðŸ’© kick star turd', '0');

		SELECT "SUCCESS123";
		
   COMMIT;
   
end//
delimiter ;

-- Not needed because the command line invocation of mysql specifies the database.
-- Use SyncServer_SharedImages;

call migration();
drop procedure migration;

