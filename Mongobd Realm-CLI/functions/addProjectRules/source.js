exports = async function(projectPartition) {
  
  const collection = context.services.get("mongodb-atlas").db("tracker").collection("User");
  const localUserID = context.user.id
  if (localUserID == null) {
    return {error: ` No userID found`};
  }
  if (collection == null) {
    return {error: ` No user collection`};
  }
  if (projectPartition == null) {
    return {error: ` No project partition`};
  }
  
  try {
    return await collection.updateOne(
      
        {_id: localUserID},
        {$addToSet: { canWritePartitions: projectPartition, canReadPartitions: projectPartition }}
    );
  } catch (error) {
    return {error: error.toString()};
  }
  
};