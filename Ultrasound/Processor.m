//
//  Processor.m
//  Ultrasound
//
//  Created by AppDev on 7/3/13.
//  Copyright (c) 2013 AppDev. All rights reserved.
//

#import "Processor.h"
#import "ProcessAlgoMain.h"
#import "NSData+AES256.h"

//#define kNumberLength 25.0

@implementation Processor

+ (void) incrementCountForKey:(id)key inDictionary:(NSMutableDictionary *)dict
{
    NSNumber *count = [dict objectForKey:key];
    if(count)
    {
        [dict setObject:@(count.intValue + 1) forKey:key];
    }
    else
    {
        [dict setObject:@(1) forKey:key];
    }
}


+ (NSArray *) processPacketData:(NSArray *) packetData
{
    NSMutableArray *result = [NSMutableArray array];
    NSArray *distanceSpacing = nil;
    double fallbackPacketLength = [ProcessAlgoMain getDistanceSpacingFallback:packetData andDistancesIntoArray:&distanceSpacing];
    //int numSections = ceil(packetData.count / fallbackPacketLength);
    
    double increment = [distanceSpacing[0] doubleValue];
    BOOL needToSync = NO;
    int syncCounter = 0;
    int distanceIndex = 0;
    
    double lastIncrement = 0;
    for (int i = 0; i < packetData.count; i += lastIncrement)
    {
        BOOL isFakeData = increment < fallbackPacketLength * 0.5;
        if (increment > fallbackPacketLength * 1.5)
        {
            syncCounter = round(increment / fallbackPacketLength);
            increment = increment / syncCounter;
            lastIncrement = increment;
            distanceIndex++;
//            needToSync = YES;
        }
        
        if(!isFakeData)
        {
            NSMutableArray *subData = [NSMutableArray array];
            //printf("Start sub data: %i\nEnd sub data:%i\n", i, (int)(i + increment - 1));
            for (int j = i; j < i + increment - 1; j++)
            {
                [subData addObject:packetData[j]];
            }

            int mode = [self findModeForArray:subData];
            [result addObject:@(mode)];
        }
        
        if (syncCounter > 0)
        {
            syncCounter--;
            if (syncCounter == 0)
            {
                needToSync = YES;
            }
        }
        else
        {
            lastIncrement = increment;
            
            distanceIndex++;
            if(distanceIndex >= distanceSpacing.count)
            {
                break;
            }
            increment = [distanceSpacing[distanceIndex] doubleValue];
        }
        
        if (needToSync)
        {
            if(distanceIndex >= distanceSpacing.count)
            {
                break;
            }
            
            NSLog(@"Sync");
            
            int sum = 0;
            for (int j = 0; j < distanceIndex; j++)
            {
                sum += [distanceSpacing[j] intValue];
            }
            
            i = sum - increment + 1;
            lastIncrement = increment;
            increment = [distanceSpacing[distanceIndex] intValue];
            needToSync = NO;
        }
    }
    return [result copy];
}

+ (double) findMin: (NSArray *) array
{
    NSArray *temp = [array copy];
    temp = [temp sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        if ([obj2 intValue] > [obj1 intValue])
        {
            return NSOrderedAscending;
        }
        else if([obj2 intValue] < [obj1 intValue])
        {
            return NSOrderedDescending;
        }
        else
        {
            return NSOrderedSame;
        }
    }];
            
    return [temp[0] doubleValue];
}

+ (int) findModeForArray: (NSArray *) array
{
    NSMutableDictionary *dataSet = [NSMutableDictionary dictionary];
   
    for (int i = 0; i < array.count; i++)
    {
        [self incrementCountForKey:array[i] inDictionary:dataSet];
    }
    
    int maxCount = 0;
    int mode = 0;
    for(NSNumber *value in dataSet)
    {
        int count = [[dataSet objectForKey:value] intValue];
        if(count > maxCount)
        {
            maxCount = count;
            mode = [value intValue];
        }
    }
    
    return mode;
}

+ (NSArray *) combineNibbleArrayToByteArray:(NSArray *)nibbles
{
    if(nibbles.count % 2 == 1)
    {
        NSLog(@"Odd data length... returning nil!");
        return nil;
    }
    
    NSMutableArray *bytes = [NSMutableArray arrayWithCapacity:nibbles.count / 2];
    for(int i = 0; i < nibbles.count; i += 2)
    {
        int val0 = [nibbles[i+1] intValue];
        int val1 = [nibbles[i] intValue];
        int combined = val1 * 16 + val0; // 16 = 2^4
        [bytes addObject:@(combined)];
    }
    
    return bytes;
}

+ (NSArray *) splitByteArrayIntoNibbleArray:(NSArray *) bytes
{
    NSMutableArray *output = [[NSMutableArray alloc] initWithCapacity:bytes.count * 2];

    for (int i = 0; i < bytes.count; i++)
    {
        int val = [bytes[i] intValue];
        int val1 = val / 16;
        int val2 = val - val1 * 16;
        [output addObject:@(val1)];
        [output addObject:@(val2)];
    }
    
    return output;
}


+ (NSData*) encryptString:(NSString*)plaintext withKey:(NSString*)key
{
	return [[plaintext dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:key];
}

// Fun debug encoding
+ (NSArray *) encodeStringAndEncrypt:(NSString *)string withKey:(NSString *) key
{
    NSData *cipher = [self encryptString: string withKey: key];
    NSUInteger len = [cipher length];
    Byte *byteData = (Byte*) malloc(len);
    memcpy(byteData, [cipher bytes], len);
    
    NSMutableArray *bytes = [NSMutableArray arrayWithCapacity:string.length];
    for (int i = 0; i < len; i++)
    {
        [bytes addObject:@(byteData[i])];
    }
    
    free(byteData);
    
    return [self splitByteArrayIntoNibbleArray:bytes];
}

+ (NSArray *) encodeString:(NSString *)string
{
    NSMutableArray *bytes = [NSMutableArray arrayWithCapacity:string.length];
    for(int i = 0; i < string.length; i++)
    {
        unichar c = [string characterAtIndex:i];
        [bytes addObject:@(c)];
    }
    
    //return [self splitByteArrayIntoNibbleArray:bytes];
    return bytes;
}

+ (NSString *) decodeData:(NSArray *)data
{
//    NSArray *bytes = [self combineNibbleArrayToByteArray:data];
    NSArray *bytes = data;
    if(!bytes) return nil;
    
    NSMutableString *string = [NSMutableString string];
    for(int i = 0; i < bytes.count; i++)
    {
        unichar c = [bytes[i] intValue];
        [string appendFormat:@"%c", c];
    }
    
    return [string copy];
}

+ (NSString*) decryptData:(NSData*)ciphertext withKey:(NSString*)key
{
	return [[NSString alloc] initWithData:[ciphertext AES256DecryptWithKey:key] encoding:NSUTF8StringEncoding];
}

+ (NSString *) decodeDataAndDecrypt:(NSArray *)data withKey:(NSString *) key
{
    NSArray *bytes = [self combineNibbleArrayToByteArray:data];
    Byte *buffer = malloc(sizeof(Byte) * bytes.count);
    for (int i = 0; i < bytes.count; i++)
    {
        buffer[i] = [bytes[i] intValue];
    }
    
    NSData *cipher = [NSData dataWithBytes:buffer length:bytes.count];
    NSString *plainText = [self decryptData:cipher withKey:key];
    free(buffer);
    
    return plainText;
}

@end
