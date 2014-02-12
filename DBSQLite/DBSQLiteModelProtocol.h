//
//  DBSQLiteModelProtocol.h
//
//  Created by Dima Bart on 2/6/2014.
//  Copyright (c) 2014 Dima Bart. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DBSQLiteModelProtocol <NSObject>

+ (NSDictionary *)keyMapForModelObject;

@end
