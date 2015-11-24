//
//  SmartUITableView.m
//  NativeiOSBooker
//
//  Created by Danila Parkhomenko on 08/04/15.
//  Copyright (c) 2015 Booker Software. All rights reserved.
//

#import "SmartUITableView.h"

typedef enum : NSUInteger {
    TableOperationNone = 0,
    TableOperationReloadSections,
    TableOperationInsertSections,
    TableOperationDeleteSections,
    TableOperationMoveSections,
    TableOperationInsertRows,
    TableOperationDeleteRows,
} TableOperation;

static NSString *kOperation = @"Operation";
static NSString *kParameter = @"Parameter0";
static NSString *kOtherParameter = @"Parameter1";
static NSString *kAnimation = @"Animation";

@interface SectionConfig : NSObject
@property (nonatomic, assign) BOOL validRowCount;
@property (nonatomic, assign) NSInteger rowCount;
@property (nonatomic, assign) NSInteger indexBeforeUpdate;
@property (nonatomic, assign) NSInteger indexAfterUpdate;
- (id) initWithRowCount:(NSInteger) rowCount andIndex:(NSInteger) index;
- (id) initWithIndex:(NSInteger) index;
@end

@interface SmartUITableView ()

@property (nonatomic, assign) BOOL updateMode;
@property (nonatomic, strong) NSMutableArray *sectionsConfiguration;
@property (nonatomic, strong) NSMutableArray *uiOperationsQueue;
@property (nonatomic, strong) NSMutableArray *scheduledAnimations;

@end

@implementation SmartUITableView

- (NSMutableArray *) getCurrentSectionsConfiguration
{
    NSMutableArray *sectionsConfig = [NSMutableArray array];
    NSInteger sectionCount = [self.dataSource numberOfSectionsInTableView:self];
    for (NSInteger section = 0; section < sectionCount; section++) {
        [sectionsConfig addObject:[[SectionConfig alloc] initWithRowCount:[self.dataSource tableView:self numberOfRowsInSection:section]
                                                                 andIndex:section]];
    }
    return sectionsConfig;
}

- (void)beginUpdates
{
    self.updateMode = YES;
    if (self.sectionsConfiguration == nil) {
        self.sectionsConfiguration = [self getCurrentSectionsConfiguration];
    }
    self.scheduledAnimations = [NSMutableArray array];
    [super beginUpdates];
}

//- (BOOL)canEndUpdateWithNewConfig:(NSArray *)sectionConfig
//{
//    §
//}
//

- (void)performUpdates
{
    for (NSDictionary *dictionary in self.scheduledAnimations) {
        switch ([dictionary[kOperation] integerValue]) {
            case TableOperationReloadSections:
                [super reloadSections:dictionary[kParameter]
                     withRowAnimation:[dictionary[kAnimation] integerValue]];
                break;
            case TableOperationInsertSections:
                [super insertSections:dictionary[kParameter]
                     withRowAnimation:[dictionary[kAnimation] integerValue]];
                break;
            case TableOperationDeleteSections:
                [super deleteSections:dictionary[kParameter]
                     withRowAnimation:[dictionary[kAnimation] integerValue]];
                break;
            case TableOperationMoveSections:
                [super moveSection:[dictionary[kParameter] integerValue]
                         toSection:[dictionary[kOtherParameter] integerValue]];
                break;
            case TableOperationInsertRows:
                [super insertRowsAtIndexPaths:dictionary[kParameter]
                             withRowAnimation:[dictionary[kAnimation] integerValue]];
                break;
            case TableOperationDeleteRows:
                [super deleteRowsAtIndexPaths:dictionary[kParameter]
                             withRowAnimation:[dictionary[kAnimation] integerValue]];
                break;
            default:
                break;
        }
    }
}

- (void)endUpdates
{
    if (self.sectionsConfiguration) { // if nil, table was reloaded
        [self updateIndexes];
        NSMutableArray *newSectionsConfig = [self getCurrentSectionsConfiguration];
        __block BOOL somethingBadHappenned = NO;
        if (newSectionsConfig.count != self.sectionsConfiguration.count) {
            somethingBadHappenned = YES;
            NSLog(@"ERROR! Section count is different! Got %lu, but %lu was expected", (unsigned long)newSectionsConfig.count, (unsigned long)self.sectionsConfiguration.count);
            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
            NSInteger countDiff = ABS(newSectionsConfig.count - self.sectionsConfiguration.count);
            for (NSInteger i = 1; i < countDiff + 1; i++) {
                [indexSet addIndex:i];
            }
            if (newSectionsConfig.count > self.sectionsConfiguration.count) {
                NSMutableIndexSet *allSections = [NSMutableIndexSet indexSet];
                for (NSInteger i = 0; i < self.sectionsConfiguration.count; i++) {
                    [allSections addIndex:i];
                }
                [super reloadSections:allSections withRowAnimation:UITableViewRowAnimationAutomatic];
                [super insertSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                NSMutableIndexSet *allSections = [NSMutableIndexSet indexSet];
                [allSections addIndex:0];
                for (NSInteger i = countDiff + 1; i < self.sectionsConfiguration.count; i++) {
                    [allSections addIndex:i];
                }
                [super reloadSections:allSections withRowAnimation:UITableViewRowAnimationAutomatic];
                [super deleteSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        } else {
            NSMutableIndexSet *indexSetToReload = nil;
            for (NSInteger section = 0; section < self.sectionsConfiguration.count; section++) {
                SectionConfig *desiredConfig = self.sectionsConfiguration[section];
                if (!desiredConfig.validRowCount) continue;
                if (newSectionsConfig.count > desiredConfig.indexAfterUpdate) {
                    SectionConfig *actualConfig = newSectionsConfig[desiredConfig.indexAfterUpdate];
                    if (actualConfig.rowCount != desiredConfig.rowCount) {
                        if (indexSetToReload) {
                            [indexSetToReload addIndex:section];
                        } else {
                            indexSetToReload = [NSMutableIndexSet indexSetWithIndex:section];
                        }
                        NSLog(@"ERROR! Row count for section %lu is different! Got %lu instead of %lu", (long)section, (long)actualConfig.rowCount, (long)desiredConfig.rowCount);
                        break;
                    }
                } else {
                    somethingBadHappenned = YES;
                    NSLog(@"ERROR! Section count is less than expected! Got %lu instead of at least %lu", (unsigned long)newSectionsConfig.count, (long)desiredConfig.indexAfterUpdate);
                    break;
                }
            }
            if (indexSetToReload) {
                [self reloadSections:indexSetToReload withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        if (somethingBadHappenned) {
            [self reloadData];
        } else {
            [self performUpdates];
            self.sectionsConfiguration = newSectionsConfig;
        }
    } else {
        [self reloadData];
        self.sectionsConfiguration = [self getCurrentSectionsConfiguration];
    }
    self.updateMode = NO;
    @try {
        [super endUpdates];
    }
    @catch (NSException *exception) {
        NSLog(@"ERROR! Unhandled difference between tableview data source section/row count and expected row count");
        [self reloadData];
    }
}

- (void) reloadData
{
    self.sectionsConfiguration = [self getCurrentSectionsConfiguration];
    [super reloadData];
}

- (void) updateIndexes
{
    [self.sectionsConfiguration enumerateObjectsUsingBlock:^(SectionConfig *cfg, NSUInteger idx, BOOL *stop) {
        cfg.indexAfterUpdate = idx;
    }];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        __weak SmartUITableView *weakSelf = self;
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSInteger targetIndex = NSNotFound;
            for (NSInteger i = 0; i < weakSelf.sectionsConfiguration.count; i++) {
                SectionConfig *cfg = weakSelf.sectionsConfiguration[i];
                if (cfg.indexBeforeUpdate >= idx) {
                    targetIndex = i;
                    break;
                }
            }
            if (targetIndex == NSNotFound) {
                targetIndex = weakSelf.sectionsConfiguration.count;
            }
            [weakSelf.sectionsConfiguration insertObject:[[SectionConfig alloc] initWithIndex:targetIndex] atIndex:targetIndex];
        }];
        [self.scheduledAnimations addObject:@{kOperation: @(TableOperationInsertSections),
                                              kParameter: sections,
                                              kAnimation: @(animation)}];
    } else {
        [self beginUpdates];
        [self insertSections:sections withRowAnimation:animation];
        [self endUpdates];
    }
}

- (SectionConfig *) sectionAtExactIndex:(NSInteger) idx
{
    for (SectionConfig *cfg in self.sectionsConfiguration) {
        if (cfg.indexBeforeUpdate == idx)
            return cfg;
    }
    return nil;
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        __weak SmartUITableView *weakSelf = self;
        __block BOOL found = NO;
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            SectionConfig *cfg = [weakSelf sectionAtExactIndex:idx];
            if (cfg) {
                [weakSelf.sectionsConfiguration removeObject:cfg];
                found = YES;
            }
        }];
        if (found) {
            [self.scheduledAnimations addObject:@{kOperation: @(TableOperationDeleteSections),
                                                  kParameter: sections,
                                                  kAnimation: @(animation)}];
        } else {
            [self reloadData];
        }
    } else {
        //dispatch_async(dispatch_get_main_queue(), ^{
            [self beginUpdates];
            [self deleteSections:sections withRowAnimation:animation];
            [self endUpdates];
        //});
    }
}

//- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
//{
//    [super reloadSections:sections withRowAnimation:animation];
//}
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        __block BOOL allSectionsFound = YES;
        __weak SmartUITableView *weakSelf = self;
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            SectionConfig *desiredConfig = [weakSelf sectionAtExactIndex:idx];
            if (desiredConfig) {
                desiredConfig.validRowCount = NO;
            } else {
                allSectionsFound = NO;
                *stop = YES;
            }
        }];
        if (allSectionsFound) {
            [self.scheduledAnimations addObject:@{kOperation: @(TableOperationReloadSections),
                                                  kParameter: sections,
                                                  kAnimation: @(animation)}];
        } else {
            [self reloadData];
        }
    } else {
        [self beginUpdates];
        [self reloadSections:sections withRowAnimation:animation];
        [self endUpdates];
    }
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    if (self.updateMode) {
        __weak SmartUITableView *weakSelf = self;
        for (NSInteger i = 0; i < weakSelf.sectionsConfiguration.count; i++) {
            SectionConfig *source = weakSelf.sectionsConfiguration[i];
            if (source.indexBeforeUpdate == section) {
                [weakSelf.sectionsConfiguration removeObjectAtIndex:i];
                NSInteger destinationIndex = NSNotFound;
                for (NSInteger j = 0; j < weakSelf.sectionsConfiguration.count; j++) {
                    SectionConfig *destination = weakSelf.sectionsConfiguration[j];
                    if (destination.indexBeforeUpdate >= newSection) {
                        destinationIndex = j;
                        break;
                    }
                }
                if (destinationIndex == NSNotFound) {
                    [weakSelf.sectionsConfiguration addObject:source];
                } else {
                    [weakSelf.sectionsConfiguration insertObject:source atIndex:destinationIndex];
                }
                break;
            }
        }
        [self.scheduledAnimations addObject:@{kOperation: @(TableOperationMoveSections),
                                              kParameter: @(section),
                                              kOtherParameter:@(newSection)}];
    } else {
        [self beginUpdates];
        [self moveSection:section toSection:newSection];
        [self endUpdates];
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        BOOL everyPathIsFound = YES;
        for (NSIndexPath *indexPath in indexPaths) {
            SectionConfig *cfg = [self sectionAtExactIndex:indexPath.section];
            if (cfg) {
                cfg.rowCount++;
            } else {
                everyPathIsFound = NO;
            }
        }
        if (everyPathIsFound) {
            [self.scheduledAnimations addObject:@{kOperation: @(TableOperationInsertRows),
                                                  kParameter: indexPaths,
                                                  kAnimation: @(animation)}];
        } else {
            [self reloadData];
        }
    } else {
        [self beginUpdates];
        [self insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self endUpdates];
    }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        __block NSMutableArray *existingIndexPaths = [NSMutableArray array];
        NSMutableIndexSet *problematicSections = nil;
        BOOL gotNonExistingSection = NO;
        for (NSIndexPath *indexPath in indexPaths) {
            SectionConfig *cfg = [self sectionAtExactIndex:indexPath.section];
            if (cfg) {
                [existingIndexPaths addObject:indexPath];
                if (cfg.rowCount) {
                    cfg.rowCount--;
                } else {
                    if (problematicSections) {
                        [problematicSections addIndex:indexPath.section];
                    } else {
                        problematicSections = [NSMutableIndexSet indexSet];
                    }
                }
            } else {
                gotNonExistingSection = YES;
            }
        }
        if (gotNonExistingSection) {
            [self reloadData];
        } else {
            [problematicSections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
                for (NSInteger i = existingIndexPaths.count; i--; ) {
                    NSIndexPath *indexPath = existingIndexPaths[i];
                    if (indexPath.section == section) {
                        [existingIndexPaths removeObjectAtIndex:i];
                    }
                }
            }];
            if (problematicSections.count) {
                [self reloadSections:problematicSections withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            if (existingIndexPaths.count) {
                [self.scheduledAnimations addObject:@{kOperation: @(TableOperationDeleteRows),
                                                      kParameter: indexPaths,
                                                      kAnimation: @(animation)}];
            }
        }
    } else {
        [self beginUpdates];
        [self deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self endUpdates];
    }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    if ((self.sectionsConfiguration.count > 0) && (indexPath.section >= 0)) {
        if (self.sectionsConfiguration.count <= indexPath.section) {
            [self scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:self.sectionsConfiguration.count - 1] atScrollPosition:scrollPosition animated:animated];
        } else {
            SectionConfig *config = (SectionConfig *)self.sectionsConfiguration[indexPath.section];
            if (config.validRowCount) {
                @try {
                    if (config.rowCount > indexPath.row) {
                        [super scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
                    } else {
                        NSLog(@"ERROR! scrollToRowAtIndexPath:atScrollPosition:animated: can't scroll to row %ld of section %ld", (long)indexPath.row, (long)indexPath.section);
                        [super scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:config.rowCount - 1 inSection:indexPath.row] atScrollPosition:scrollPosition animated:animated];
                    }
                }
                @catch (NSException *exception) {
                    NSLog(@"ERROR! scrollToRowAtIndexPath:atScrollPosition:animated: got exception %@", exception.description);
                }
                @try {
                    [self reloadData];
                }
                @catch (NSException *exception) {
                    NSLog(@"ERROR! reloadData failed after scrollToRowAtIndexPath:atScrollPosition:animated: got exception %@", exception.description);
                }
            } else {
                NSLog(@"ERROR! scrollToRowAtIndexPath:atScrollPosition:animated: can't scroll to row %ld of section %ld. Section is being reloaded", (long)indexPath.row, (long)indexPath.section);
            }
        }
    } else {
        NSLog(@"ERROR! scrollToRowAtIndexPath:atScrollPosition:animated: can't scroll to row %ld of section %ld. Table is being reloaded", (long)indexPath.row, (long)indexPath.section);
    }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.sectionsConfiguration.count > 0) {
        NSMutableArray *validIndexPaths = [NSMutableArray array];
        for (NSIndexPath *indexPath in indexPaths) {
            if ((indexPath.section >= 0) && (self.sectionsConfiguration.count > indexPath.section)) {
                SectionConfig *config = (SectionConfig *)self.sectionsConfiguration[indexPath.section];
                if (config.validRowCount && (config.rowCount > indexPath.row)) {
                    [validIndexPaths addObject:indexPath];
                }
            }
        }
        @try {
            if (validIndexPaths.count > 0) {
                [super reloadRowsAtIndexPaths:validIndexPaths withRowAnimation:animation];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"ERROR! reloadRowsAtIndexPaths:withRowAnimation: got exception %@", exception.description);
            [self reloadData];
        }
    }
}
//
//- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
//{
//    [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
//}

@end
                
@implementation SectionConfig

- (id) initWithIndex:(NSInteger)index
{
    if (self = [super init]) {
        self.indexBeforeUpdate = index;
        self.validRowCount = NO;
    }
    return self;
}

- (id) initWithRowCount:(NSInteger)rowCount andIndex:(NSInteger)index
{
    if (self = [self initWithIndex:index]) {
        self.rowCount = rowCount;
        self.validRowCount = YES;
    }
    return self;
}

@end
