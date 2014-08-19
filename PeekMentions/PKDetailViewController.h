//
//  PKDetailViewController.h
//  PeekMentions
//
//  Created by James Barclay on 8/13/14.
//  Copyright (c) 2014 Everything is Gray. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PKDetailViewController : UIViewController {
    IBOutlet UIImageView *profileImage;
    IBOutlet UILabel *usernameLabel;
    IBOutlet UILabel *tweetLabel;
}

@property (strong, nonatomic) id detailItem;

- (IBAction)retweet:(id)sender;

@end
