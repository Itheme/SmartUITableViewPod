//
//  SmartUITableView.m
//  NativeiOSBooker
//
//  Created by Danila Parkhomenko on 08/04/15.
//  Copyright (c) 2015 Booker Software. All rights reserved.
//

#import "SmartUITableView.h"

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
    [super beginUpdates];
}

//- (BOOL)canEndUpdateWithNewConfig:(NSArray *)sectionConfig
//{
//    §
//}
//
- (void)endUpdates
{
    if (self.sectionsConfiguration) { // if nil, table was reloaded
        [self updateIndexes];
        NSMutableArray *newSectionsConfig = [self getCurrentSectionsConfiguration];
        __block BOOL somethingBadHappenned = NO;
        if (newSectionsConfig.count != self.sectionsConfiguration.count) {
            somethingBadHappenned = YES;
            NSLog(@"ERROR! Section count is different! Got %lu, but %d was expected", (unsigned long)newSectionsConfig.count, self.sectionsConfiguration.count);
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
            self.sectionsConfiguration = newSectionsConfig;
        }
    } else {
        self.sectionsConfiguration = [self getCurrentSectionsConfiguration];
    }
    self.updateMode = NO;
    [super endUpdates];
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
        [super insertSections:sections withRowAnimation:animation];
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
            [super deleteSections:sections withRowAnimation:animation];
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
        [super moveSection:section toSection:newSection];
    } else {
        [self beginUpdates];
        [self moveSection:section toSection:newSection];
        [self endUpdates];
    }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.updateMode) {
        for (NSIndexPath *indexPath in indexPaths) {
            SectionConfig *cfg = [self sectionAtExactIndex:indexPath.section];
            if (cfg) {
                cfg.rowCount++;
            }
        }
        [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
    } else {
        [self beginUpdates];
        [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
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
                [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
            }
        }
    } else {
        [self beginUpdates];
        [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
        [self endUpdates];
    }
}

//- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
//{
//    [super reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
//}
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
