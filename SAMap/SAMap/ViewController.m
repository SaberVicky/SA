//
//  ViewController.m
//  SAMap
//
//  Created by Saber on 2017/12/27.
//  Copyright © 2017年 mfw.com. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>

@interface City : NSObject
@property (nonatomic, assign) double x;
@property (nonatomic, assign) double y;
@end
@implementation City
@end


#define T_Start 50000.0     //初始温度
#define T_End   0.00000001  //终止温度
#define k       0.98        //降温系数
#define LOOP    1000        //每个温度时的迭代次数

//初始化数据
NSMutableArray *initData() {

    NSData *JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"china" ofType:@"json"]];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:nil];
    NSArray *arr = [dic allValues];
    NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:arr.count];
    for (int i = 0; i < arr.count; i++) {
        City *c = [City new];
        NSArray *cArr = arr[i];
        c.x = [cArr[1] doubleValue];
        c.y = [cArr[0] doubleValue];
        [mArr addObject:c];
    }
    return mArr;
}

//随机交换数组里的两个元素
void randomSwap2Element(NSMutableArray *arr) {
    NSInteger index1 = arc4random() % arr.count;
    NSInteger index2 = arc4random() % arr.count;
    [arr exchangeObjectAtIndex:index1 withObjectAtIndex:index2];
}

//计算两城市之间距离
double distance(City *c1, City *c2) {
    return sqrt((c1.x-c2.x)*(c1.x-c2.x) + (c1.y-c2.y)*(c1.y-c2.y));
}

//计算路线总和
double pathLength(NSArray<City *> *arr) {
    double length = 0;
    for (int i = 0; i < arr.count - 1; i++) {
        City *c1 = arr[i];
        City *c2 = arr[i+1];
        length += distance(c1, c2);
    }
    
    City *cFirst = arr[0];
    City *cLast = arr[arr.count - 1];
    double dis = distance(cFirst, cLast);
    return length + dis;
}

@interface MyAnnotation : NSObject<MKAnnotation>
@property (nonatomic,assign) CLLocationCoordinate2D coordinate;
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate;
@end
@implementation MyAnnotation
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
    if (self = [super init]) {
        self.coordinate = coordinate;
    }
    return self;
}
@end

@interface ViewController ()<MKMapViewDelegate>
{
    CLLocationManager *_locationManager;
}

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPolyline *currentLine;
@property (nonatomic, strong) NSMutableArray *allPathArr;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger timeCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _allPathArr = [NSMutableArray array];
    
    _locationManager = [[CLLocationManager alloc]init];
    [_locationManager requestWhenInUseAuthorization];
    
    _mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    _mapView.delegate = self;
    [self.view addSubview:_mapView];
    
    NSMutableArray *city_list = initData();
    [self showCitys:city_list];
    [self drawline:city_list];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 100, 100, 40)];
    button.backgroundColor = [UIColor blueColor];
    [button setTitle:@"Start" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(clickBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)showCitys:(NSArray *)citys {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:citys.count];
    for (City *c in citys) {
            MyAnnotation *a = [[MyAnnotation alloc] initWithCoordinate:CLLocationCoordinate2DMake(c.x, c.y)];
        [arr addObject:a];
    }
    [_mapView addAnnotations:arr];
}

- (void)clickBtn {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        double T = T_Start;
        double df, newLength, random;
        int count = 0;
        
        NSMutableArray *currentPath = initData();
        [self drawline:currentPath];
        double oldLength = pathLength(currentPath);
        
        NSArray *currentBestPath = currentPath.copy;
        int loopCount = 0;
        while (T > T_End) {
            
            for (int i = 0; i < LOOP; i++) {
                randomSwap2Element(currentPath);
                newLength = pathLength(currentPath);
                df = newLength - oldLength;
                
                if (df <= 0) {
                    oldLength = newLength;
                    currentBestPath = currentPath.copy;
                } else {
                    random = ((double)rand())/(RAND_MAX);
                    if (exp(-df/T) > random) {
                        oldLength = newLength;
                        currentBestPath = currentPath.copy;
                    } else {
                        currentPath = currentBestPath.mutableCopy;
                    }
                }
                if (loopCount % 10000 == 0) {
                    [self addPath:currentPath.copy];
                }
                loopCount++;
            }
            
            T*=k;
            count++;
        }
        
        NSLog(@"总共降温  %d 次", count);
        NSLog(@"最短距离为 %lf", oldLength);
    });
    
    [self showAnimation];
}

- (void)showAnimation {
    _timer = [NSTimer timerWithTimeInterval:.2 target:self selector:@selector(timerCount) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)timerCount {
    
    if (_timeCount >= _allPathArr.count) {
        [_timer invalidate];
        _timer = nil;
        return;
    }
    
    [self drawline:_allPathArr[_timeCount]];
    
    _timeCount++;
}

- (void)addPath:(NSArray *)arr {
    if (!arr) {
        return;
    }
    [_allPathArr addObject:arr];
}

-(void) drawline: (NSArray*)cityArr
{
    [_mapView removeOverlay:_currentLine];
    //  将array中的信息点转换成CLLocationCoordinate2D数组
    CLLocationCoordinate2D coords[cityArr.count];
    
    int i = 0;
    for (City *c in cityArr) {
        CLLocationCoordinate2D annotationCoord;
        annotationCoord.latitude = c.x;
        annotationCoord.longitude = c.y;
        coords[i] = annotationCoord;
        i++;
    }
    
    _currentLine = [MKPolyline polylineWithCoordinates:coords count:cityArr.count];
    [_mapView addOverlay:_currentLine];
}

#pragma mark - MapView Delegate
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *render = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
        render.strokeColor = [UIColor colorWithRed:69.0f/255.0f green:212.0f/255.0f blue:255.0f/255.0f alpha:0.9];
        render.lineWidth = 8.0;
        return render;
    }
    return nil;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"123"];
    if (!annotationView) {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"123"];
    }

    annotationView.image = [UIImage imageNamed:@"red_dot"];
    return annotationView;
}


- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end
