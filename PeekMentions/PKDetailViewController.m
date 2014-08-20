//
//  PKDetailViewController.m
//  PeekMentions
//
//  Created by James Barclay on 8/13/14.
//  Copyright (c) 2014 Everything is Gray. All rights reserved.
//

#import <Social/Social.h>
#import <Accounts/Accounts.h>

#import "PKDetailViewController.h"
#import "PKConstants.h"

@interface PKDetailViewController ()

@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableData *buffer;
@property (strong, nonatomic) NSMutableArray *results;
@property (strong, nonatomic) ACAccountStore *accountStore;

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

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil) {
        _accountStore = [[ACAccountStore alloc] init];
    }

    return _accountStore;
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        NSDictionary *tweet = self.detailItem;

        NSString *text = tweet[@"text"];
        NSString *username = tweet[@"user"][@"name"];

        tweetLabel.lineBreakMode = NSLineBreakByWordWrapping;
        tweetLabel.numberOfLines = 0;

        usernameLabel.text = username;
        tweetLabel.text = text;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *imageURL = tweet[@"user"][@"profile_image_url"];
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];

            dispatch_async(dispatch_get_main_queue(), ^{
                profileImage.image = [UIImage imageWithData:data];
            });
        });
    }
}

- (void)retweetTweetWithID:(NSString *)tweetID
{
    // Set the accountType to Twitter
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    // Request access to the Twitter account, then retweet the tweet
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:^(BOOL granted, NSError *error) {
        if (granted) {
            NSString *urlString = [kTwitterRetweetURL stringByAppendingString:[tweetID stringByAppendingPathExtension:@"json"]];
            NSURL *url = [NSURL URLWithString:urlString];
            NSDictionary *params = @{@"trim_user": @"true"};
            SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                      requestMethod:SLRequestMethodPOST
                                                                URL:url
                                                         parameters:params];

            NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
            slRequest.account = [accounts lastObject];
            NSURLRequest *req = [slRequest preparedURLRequest];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
                [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
            });
        }
    }];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.buffer = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {

    [self.buffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;

    NSError *jsonParsingError = nil;
    NSDictionary *jsonResults = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];

    self.results = jsonResults[@"statuses"];

    self.buffer = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    self.buffer = nil;

    [self handleError:error];
}

- (void)handleError:(NSError *)error
{
    NSString *errorMessage = [error localizedDescription];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error"
                                                        message:errorMessage
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)cancelConnection
{
    if (self.connection != nil)
    {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self.connection cancel];
        self.connection = nil;
        self.buffer = nil;
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];

    if ([title isEqualToString:@"Retweet"]) {
        NSDictionary *tweet = self.detailItem;
        NSString *tweetID = [tweet[@"id"] stringValue];
        [self retweetTweetWithID:tweetID];
    } else {
        NSLog(@"The user canceled the retweet.");
    }
}

- (IBAction)retweet:(id)sender
{
    if (self.detailItem) {
        NSDictionary *tweet = self.detailItem;
        NSString *text = tweet[@"text"];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Retweet to your followers?"
                                                            message:text
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Retweet", nil];
        [alertView show];
    }
}

@end
