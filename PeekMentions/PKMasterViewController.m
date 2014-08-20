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

    [self fetchPeekTweets];
}

- (void)stopRefresh
{
    [self.refreshControl endRefreshing];
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

- (unsigned long long)getSmallestTweetIDIn:(NSDictionary *)jsonResults
{
    // Assign smallest ID to unsigned long long max temporarily
    unsigned long long smallestID = ULLONG_MAX;

    for (NSDictionary *dct in jsonResults[@"statuses"]) {
        NSNumber *currentID = dct[@"id"];
        NSLog(@"currentID: %@", currentID);
        NSLog(@"currentID unsigned long long: %llu", [currentID unsignedLongLongValue]);
        if ([currentID unsignedLongLongValue] < smallestID) {
            smallestID = [currentID unsignedLongLongValue];
        }
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

             if (maxTweetID != 0) {
                 NSLog(@"We have a minimum tweet ID. It is: %llu.", maxTweetID);
                 [mutableParams setObject:[[NSNumber numberWithUnsignedLongLong:maxTweetID - 1] stringValue] forKey:@"max_id"];
                 NSLog(@"mutableParams are now: %@", mutableParams);
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

//    self.results = jsonResults[@"statuses"];
    if ([self.results count]) {
        NSLog(@"_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_*_");
        NSLog(@"Adding this array to results: %@", jsonResults[@"statuses"]);
        [self.results addObjectsFromArray:jsonResults[@"statuses"]];
    } else {
        self.results = [jsonResults[@"statuses"] mutableCopy];
    }

    if (jsonResults != nil) {
    //    self.smallestTweetID = [self getMinimumTweetIDIn:jsonResults];
        maxTweetID = [self getSmallestTweetIDIn:jsonResults];
    //    NSLog(@"min ID in tweets is %@.", self.smallestTweetID);
        NSLog(@"min ID in tweets is %llu.", maxTweetID);
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = [self.results count];
    NSLog(@"[self.results count]: %lu", (unsigned long)count);
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView_
{
    CGFloat actualPosition = scrollView_.contentOffset.y;
    CGFloat contentHeight = scrollView_.contentSize.height - 500.0;
    NSLog(@"actualPosition: %f, contentHeight: %f", actualPosition, contentHeight);

    if (actualPosition >= 0 && contentHeight >= 0 && actualPosition >= contentHeight) {
        [self fetchPeekTweets];
        [self.tableView reloadData];
        NSLog(@"I'm gonna update some stuff.");
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
