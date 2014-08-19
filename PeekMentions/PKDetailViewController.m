//
//  PKDetailViewController.m
//  PeekMentions
//
//  Created by James Barclay on 8/13/14.
//  Copyright (c) 2014 Everything is Gray. All rights reserved.
//

#import "PKDetailViewController.h"

@interface PKDetailViewController ()

- (void)configureView;

@end

@implementation PKDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        NSDictionary *tweet = self.detailItem;

        NSString *text = [tweet objectForKey:@"text"];
        NSString *username = [[tweet objectForKey:@"user"] objectForKey:@"name"];

        tweetLabel.lineBreakMode = NSLineBreakByWordWrapping;
        tweetLabel.numberOfLines = 0;

        usernameLabel.text = username;
        tweetLabel.text = text;

        // Add the retweet button
        UIImage *retweetImage = [UIImage imageNamed:@"retweet_on.png"];
        UIButton *retweetButton = [UIButton buttonWithType:UIButtonTypeCustom];
        retweetButton.frame = CGRectMake(50.0, 50.0, 16.0, 16.0);
        [retweetButton setBackgroundImage:retweetImage forState:UIControlStateNormal];
        [self.view addSubview:retweetButton];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *imageURL = [[tweet objectForKey:@"user"] objectForKey:@"profile_image_url"];
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];

            dispatch_async(dispatch_get_main_queue(), ^{
                profileImage.image = [UIImage imageWithData:data];
            });
        });
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)retweet:(id)sender
{
    NSLog(@"Retweetin' some tweets!");
}
@end
