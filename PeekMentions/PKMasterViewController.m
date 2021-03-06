//
//  PKMasterViewController.m
//  PeekMentions
//
//  Created by James Barclay on 8/13/14.
//  Copyright (c) 2014 Everything is Gray. All rights reserved.
//

#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import <limits.h>

#import "PKMasterViewController.h"
#import "PKDetailViewController.h"
#import "PKConstants.h"

#import "SVPullToRefresh.h"

@interface PKMasterViewController () {
    unsigned long long maxTweetID;
}

@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableData *buffer;
@property (strong, nonatomic) NSMutableArray *results;
@property (strong, nonatomic) ACAccountStore *accountStore;

@end

@implementation PKMasterViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.results = [[NSMutableArray alloc] init];
        maxTweetID = 0;
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set up pull-to-refresh
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to Refresh"];
    [refreshControl addTarget:self action:@selector(fetchNewArrayOfPeekTweets) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;

    // Set up infinite scrolling with SVPullToRefresh. In
    // my testing this turned out to be more reliable than
    // using the scrollViewDidScroll method and comparing
    // the actual position to the content height.
    __weak PKMasterViewController *weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        [weakSelf fetchNewPeekTweets];
    }];

    // Fetch Peek Tweets
    [self fetchPeekTweets];

    // Disable multiple selection when editing
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
}

- (void)stopRefresh
{
    [self.refreshControl endRefreshing];
}

- (void)fetchNewPeekTweets
{
    __weak PKMasterViewController *weakSelf = self;

    int64_t delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        [weakSelf fetchPeekTweets];
        [weakSelf.tableView reloadData];
        [weakSelf.tableView.infiniteScrollingView stopAnimating];
    });
}

- (void)fetchNewArrayOfPeekTweets
{
    maxTweetID = 0;
    self.results = nil;
    [self fetchPeekTweets];
}

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil) {
        _accountStore = [[ACAccountStore alloc] init];
    }

    return _accountStore;
}

- (unsigned long long)getSmallestTweetIDIn:(NSArray *)jsonResults
{
    // Assign smallest ID to unsigned long long max temporarily
    unsigned long long smallestID = ULLONG_MAX;

    for (NSDictionary *dct in jsonResults) {
        NSNumber *currentID = dct[@"id"];
        if ([currentID unsignedLongLongValue] < smallestID) {
            smallestID = [currentID unsignedLongLongValue];
        }
    }

    if (smallestID == ULLONG_MAX) {
        return 0;
    }

    return smallestID;
}

- (void)fetchPeekTweets
{
    // Set the accountType to Twitter
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    // Request access to the Twitter account, then fetch Peek Tweets
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:^(BOOL granted, NSError *error) {
         if (granted) {
             NSURL *url = [NSURL URLWithString:kTwitterSearchURL];
             NSMutableDictionary *mutableParams = [[NSMutableDictionary alloc] initWithDictionary:@{@"q": @"%40Peek", @"count": @"20"}];

             if (maxTweetID != 0 && maxTweetID != ULLONG_MAX) {
                 [mutableParams setObject:[[NSNumber numberWithUnsignedLongLong:maxTweetID - 1] stringValue] forKey:@"max_id"];
             }

             SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                       requestMethod:SLRequestMethodGET
                                                                 URL:url
                                                          parameters:mutableParams];

             NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
             slRequest.account = [accounts lastObject];
             NSURLRequest *req = [slRequest preparedURLRequest];
             NSLog(@"preparedURLRequest: %@", req);
             dispatch_async(dispatch_get_main_queue(), ^{
                 self.connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
             });
         } else {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self.tableView reloadData];
             });
         }
     }];

    [self performSelector:@selector(stopRefresh) withObject:nil afterDelay:1.5];
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

    if ([self.results count]) {
        NSMutableArray *resultsWithoutDupes = [NSMutableArray array];

        for (NSDictionary *dct in jsonResults[@"statuses"]) {
            BOOL matchFound = NO;
            NSString *theID = [dct[@"id"] stringValue];

            for (NSDictionary *otherDct in self.results) {
                if ([[otherDct[@"id"] stringValue] isEqualToString:theID]) {
                    matchFound = YES;
                    break;
                }
            }
            if (!matchFound) {
                [resultsWithoutDupes addObject:dct];
            }
        }
        [self.results addObjectsFromArray:resultsWithoutDupes];
        if (resultsWithoutDupes != nil) {
            maxTweetID = [self getSmallestTweetIDIn:resultsWithoutDupes];
        } else {
            maxTweetID = [self getSmallestTweetIDIn:self.results];
        }
    } else {
        self.results = [jsonResults[@"statuses"] mutableCopy];
        if (jsonResults != nil) {
            maxTweetID = [self getSmallestTweetIDIn:jsonResults[@"statuses"]];
        } else {
            maxTweetID = [self getSmallestTweetIDIn:self.results];
        }
    }

    self.buffer = nil;
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
    [self.tableView flashScrollIndicators];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    self.buffer = nil;
    [self.refreshControl endRefreshing];

    [self handleError:error];
    [self.tableView reloadData];
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

#pragma mark - Table View

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.results removeObjectAtIndex:indexPath.row];
        [self.tableView reloadData];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = [self.results count];
    return count > 0 ? count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TweetCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    NSDictionary *tweet = [self.results objectAtIndex:indexPath.row];
    NSString *text = tweet[@"text"];
    NSString *name = tweet[@"user"][@"name"];

    if (text) cell.textLabel.text = text;
    if (name) cell.detailTextLabel.text = [NSString stringWithFormat:@"By %@", name];
    cell.imageView.image = [UIImage imageNamed:@"default_profile_image.png"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *imageURL = tweet[@"user"][@"profile_image_url"];
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];

        dispatch_async(dispatch_get_main_queue(), ^{
            cell.imageView.image = [UIImage imageWithData:data];
        });
    });

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Set up alternating row colors.
    // Use yellow because Peek likes that. :)
    if (indexPath.row % 2 == 0) {
        cell.backgroundColor = [UIColor whiteColor];
    } else {
        cell.backgroundColor = [UIColor colorWithRed:0.99 green:0.97 blue:0.84 alpha:1.0f];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showPeekTweet"]) {
        NSInteger row = [[self tableView].indexPathForSelectedRow row];
        NSDictionary *tweet = [self.results objectAtIndex:row];

        PKDetailViewController *dvc = segue.destinationViewController;
        dvc.detailItem = tweet;
    }
}

@end
