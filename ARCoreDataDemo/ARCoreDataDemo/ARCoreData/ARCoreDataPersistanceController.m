//
//  ARCoreDataPersistanceController.m
//  ARCoreDataDemo
//
//  Created by 刘平伟 on 14-7-1.
//  Copyright (c) 2014年 lPW. All rights reserved.
//

#import "ARCoreDataPersistanceController.h"

static ARCoreDataPersistanceController *AR__CoreDataPersistanceCtr = nil;

@implementation ARCoreDataPersistanceController
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

#pragma mark - init methods

/**
 *  单例
 *
 *  @return 静态的CoreDataPersistanceController
 */

+(instancetype)sharePersistanceController
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"share");
        AR__CoreDataPersistanceCtr = [[ARCoreDataPersistanceController alloc] init];
    });
    return AR__CoreDataPersistanceCtr;
}

#pragma mark - Custom methods

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

-(void)fetchAllObjectsWithEntityName:(NSString *)entityName finishedBlock:(void (^)(NSArray *, NSError *))block
{
    NSEntityDescription *EDes = [NSEntityDescription entityForName:entityName
                                            inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
    [fetchReq setEntity:EDes];
    
    NSError *error;
    NSArray *objects = [self.managedObjectContext executeFetchRequest:fetchReq error:&error];
    block(objects,error);
}

-(void)deleteObjects:(NSSet *)objects finishedBlock:(void (^)(NSError *))block{
    NSError *error;
    [objects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [self.managedObjectContext deleteObject:obj];
    }];
    [self.managedObjectContext save:&error];
    
    block(error);
}

-(void)insertObjectsWithEntityName:(NSString *)entityName attresAndValsArr:(NSArray *)attresAndValsArr finishedBlock:(void (^)(NSError *))block
{
    NSError *error;
    [attresAndValsArr enumerateObjectsUsingBlock:^(NSDictionary *attresAndVals, NSUInteger idx, BOOL *stop) {
        static NSArray *allPropertys = nil;
        NSManagedObject *newObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.managedObjectContext];
        if (allPropertys == nil) {
            allPropertys = [[[newObj entity] attributesByName] allKeys];
        }
        [attresAndVals enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([allPropertys containsObject:key]) {
                [newObj setValue:obj forKey:key];
            }else{
                NSLog(@"attresAndValsArr index %ld compoment has't key %@",idx,key);
            }
        }];
        
    }];
    
    [self.managedObjectContext save:&error];
    block(error);
}

#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
//        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    _managedObjectContext = [[NSManagedObjectContext alloc] init];

        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
//    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    /**
     *  获取资源文件里面CoreData模型文件数组最后一个
     */
    
//    NSURL *modelURL = [[[NSBundle mainBundle] URLsForResourcesWithExtension:@"momd" subdirectory:nil] lastObject];
//    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSLog(@"manage object model version %@",[_managedObjectModel entityVersionHashesByName]);
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"AR_CoreData.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSDictionary *persistentStoreOptions = @{ // Light migration
                                             NSInferMappingModelAutomaticallyOption:@YES,
                                             NSMigratePersistentStoresAutomaticallyOption:@YES
                                             };
    
    NSPersistentStore *persistanceStore = [_persistentStoreCoordinator
                                           addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                           URL:storeURL
                                           options:persistentStoreOptions
                                           error:&error];
    
    if (!persistanceStore) {
        NSLog(@"persistance store may has changed");
        error = nil;
        if ([self removeSQLiteFilesAtStoreURL:storeURL error:&error]) {
            persistanceStore = [_persistentStoreCoordinator
                                addPersistentStoreWithType:NSSQLiteStoreType
                                configuration:nil
                                URL:storeURL
                                options:persistentStoreOptions
                                error:&error];
        }else{
            NSLog(@"could not remove has changed sqilte");
        }
    }
    
    return _persistentStoreCoordinator;
}

- (BOOL)removeSQLiteFilesAtStoreURL:(NSURL *)storeURL error:(NSError * __autoreleasing *)error {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *storeDirectory = [storeURL URLByDeletingLastPathComponent];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:storeDirectory
                                          includingPropertiesForKeys:nil
                                                             options:0
                                                        errorHandler:nil];
    
    NSString *storeName = [storeURL.lastPathComponent stringByDeletingPathExtension];
    for (NSURL *url in enumerator) {
        
        if ([url.lastPathComponent hasPrefix:storeName] == NO) {
            continue;
        }
        
        NSError *fileManagerError = nil;
        if ([fileManager removeItemAtURL:url error:&fileManagerError] == NO) {
            
            if (error != NULL) {
                *error = fileManagerError;
            }
            
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Application's Documents directory

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}


@end
