package perlchartdir;
require 5.004;

my $CDPLVersion = 0x500;

sub autoImport
{
	my $ver = shift;
	if (!(eval "
		package $ver;
		require DynaLoader;
		\@ISA = qw(DynaLoader);
		bootstrap $ver;
		sub perlchartdir::major_ver { return &major_ver; };
		sub perlchartdir::minor_ver { return &minor_ver; }
		sub perlchartdir::copyright { return &copyright; }
		sub perlchartdir::id { return &id; }
		sub perlchartdir::callMethod { return &callMethod; }
		") && ($@)) {
		die;
	}
}

if ($] >= 5.008) {
	use Config;
	my $cdlibext = ($] >= 5.01) ? (($] >= 5.012) ? (($] >= 5.014) ? "514" : "512") : "510") : "58";
	if ($Config{"use64bitint"} && (4 < $Config{"ivsize"})) {
		$cdlibext .= "i64";
	}
	if (($Config{"useithreads"}) || ($Config{"use5005threads"})) {
		$cdlibext .= "mt";
	}
	autoImport("perlchartdir".$cdlibext);
}
elsif ($] >= 5.006) {
	use Config;
	if (($Config{"useithreads"}) || ($Config{"use5005threads"})) {
		if ($Config{"use64bitint"}) {
			autoImport("perlchartdir56i64mt");
		} else {
			autoImport("perlchartdir56mt");
		}
	} else {
		if ($Config{"use64bitint"}) {
			autoImport("perlchartdir56i64");
		} else {
			autoImport("perlchartdir56");
		}
	}
}
elsif ($] >= 5.005) {
	autoImport("perlchartdir5005");
}
else {
	autoImport("perlchartdir5004");
}

my $dllVersion = (callMethod("getVersion") >> 16) & 0x7fff;
if ($dllVersion != $CDPLVersion)
{
	my $majorCDV = ($CDPLVersion >> 8) & 0xff;
	my $minorCDV = $CDPLVersion & 0xff;
	my $majorv = ($dllVersion >> 8) & 0xff;
	my $minorv = $dllVersion & 0xff;
	die "Version mismatch - \"perlchartdir.pm\" is of version $majorCDV.$minorCDV, but \"chartdir.dll/libchartdir.so\" is of version $majorv.$minorv\n";
}

#///////////////////////////////////////////////////////////////////////////////////
#//	Internal functions
#///////////////////////////////////////////////////////////////////////////////////
sub checkarg
{
	my $params = shift;
	my $requiredNoOfParams = shift;
	if (!$requiredNoOfParams) { $requiredNoOfParams = 0; }
	my $actualNoOfParams = scalar(@$params);
	if ($actualNoOfParams > $requiredNoOfParams)
		{ die "Too many arguments; expecting $requiredNoOfParams but received $actualNoOfParams\n"; }
	my $noOfDefaultParams = scalar(@_);
	my $noOfMandatoryParams = $requiredNoOfParams - $noOfDefaultParams;
	if ($actualNoOfParams < $noOfMandatoryParams)
		{ die "Too few arguments; need at least $noOfMandatoryParams but received $actualNoOfParams\n"; }
	while ($actualNoOfParams < $requiredNoOfParams)
	{
		push(@$params, $_[$noOfDefaultParams + $actualNoOfParams - $requiredNoOfParams]);
		++$actualNoOfParams;
	}	
	return $params;
}

sub printerr
{
	my ($msg, $methodName) = @_;
	chop $msg;
	my $i = 0;
	my $errmsg = "$msg\n*** Stack back trace ***\n";
	while (caller(++$i)) {
		my @context = caller($i);
		my $id = $context[3];
		if (substr($id, 0, 15) ne "perlchartdir::_") {
			if ((defined $methodName) && ($id eq "CDAutoMethod::AUTOLOAD")) { $id = $methodName; }
			$errmsg .= "calling $id at $context[1]:$context[2]\n";
		}
	}
	die $errmsg;
}

sub _f
{
	my $methodName = shift;
	my $ret = eval { 
		my $params = checkarg(@_);
		callMethod($methodName, @$params); 
		};
	if ((!$ret) && ($@)) { printerr($@, $methodName); }
	return $ret;	
}

sub _m
{
	my $methodName = shift;
	my $params = shift;
	my $self = shift(@$params);
	my $ret = eval { 
		my $params = checkarg($params, @_);
		callMethod($methodName, $self->{"this"}, @$params);
	};
	if ((!$ret) && ($@)) { printerr($@, $methodName); }
	return $ret;	
}

%classNames = (
"AngularAxis"=>undef,
"AngularMeter"=>undef,
"AreaLayer"=>undef,
"ArrayMath"=>undef,
"Axis"=>undef,
"BarLayer"=>undef,
"BaseBoxLayer"=>undef,
"BaseChart"=>undef,
"BaseMeter"=>undef,
"Box"=>undef,
"BoxWhiskerLayer"=>undef,
"CandleStickLayer"=>undef,
"CDMLTable"=>undef,
"ColorAxis"=>undef,
"ContourLayer"=>undef,
"DataSet"=>undef,
"DrawArea"=>undef,
"FinanceSimulator"=>undef,
"HLOCLayer"=>undef,
"InterLineLayer"=>undef,
"Layer"=>undef,
"LegendBox"=>undef,
"Line"=>undef,
"LineLayer"=>undef,
"LinearMeter"=>undef,
"Mark"=>undef,
"MeterPointer"=>undef,
"MultiChart"=>undef,
"PieChart"=>undef,
"PlotArea"=>undef,
"PolarAreaLayer"=>undef,
"PolarChart"=>undef,
"PolarLayer"=>undef,
"PolarLineLayer"=>undef,
"PolarSplineAreaLayer"=>undef,
"PolarSplineLineLayer"=>undef,
"PolarVectorLayer"=>undef,
"PyramidChart"=>undef,
"PyramidLayer"=>undef,
"RanTable"=>undef,
"ScatterLayer"=>undef,
"Sector"=>undef,
"SplineLayer"=>undef,
"StepLineLayer"=>undef,
"SurfaceChart"=>undef,
"TTFText"=>undef,
"TextBox"=>undef,
"TrendLayer"=>undef,
"VectorLayer"=>undef,
"XYChart"=>undef,
"WebChartViewer"=>undef
);

sub cdFindSubClass
{
	my $c = shift;
	if (exists $classNames{$c}) {
		return $c;
	}
	foreach my $s (@{"${c}::ISA"}) {
		my $ret = cdFindSubClass($s);
		if (defined $ret) {
			return $ret;
		}
	}
	return undef;
}
	
sub cdFindDefaultArgs
{
	my ($c, $varName) = @_;
	my $ret = ${"${c}::defaultArgs"};
	if (defined $ret) {
		my $ret = $$ret{$varName};
		if (defined $ret) {
			return $ret;
		}
	}
	foreach my $s (@{"${c}::ISA"}) {
		my $ret = cdFindDefaultArgs($s, $varName);
		if (defined $ret) {
			return $ret;
		}
	}
	return undef;	
}

sub _r
{
	my ($fullName, $args) = @_;
	my $pos = rindex($fullName, "::");
	my $className = substr($fullName, 0, $pos);
	my $methodName = substr($fullName, $pos + 2);
	$className = cdFindSubClass($className);
	my $params = cdFindDefaultArgs($className, $methodName);
	if ($params) {
		my @dargs = @$params;
		shift @dargs;
		my $ret = _m("$className.$methodName", $args, @dargs);
		my $maker = $$params[0];
		if (defined $maker) {
			return eval(("new $maker('$ret')" =~ /(.*)/)[0]);
		} else {
			return $ret;
		}		
	} else {
		return _m("$className.$methodName", $args, scalar(@$args) - 1);
	}
}

sub encodeIfArray
{
	my ($b, $a) = @_;
	if (ref($a)) { return $b."2"; }
	return $b;
}

sub decodePtr
{
	my ($p) = @_;
	if (!defined $p) { return '$$pointer$$null'; }
	if (ref($p)) { return $p->{"this"}; }
	return $p;
}

#///////////////////////////////////////////////////////////////////////////////////
#//	constants
#///////////////////////////////////////////////////////////////////////////////////

$BottomLeft = 1;
$BottomCenter = 2;
$BottomRight = 3;
$Left = 4;
$Center = 5;
$Right = 6;
$TopLeft = 7;
$TopCenter = 8;
$TopRight = 9;
$Top = $TopCenter;
$Bottom = $BottomCenter;
$TopLeft2 = 10;
$TopRight2 = 11;
$BottomLeft2 = 12;
$BottomRight2 = 13;

$Transparent = 0xff000000;
$Palette = 0xffff0000;
$BackgroundColor = 0xffff0000; 
$LineColor = 0xffff0001;
$TextColor = 0xffff0002;
$DataColor = 0xffff0008;
$SameAsMainColor = 0xffff0007;

$HLOCDefault = 0;
$HLOCOpenClose = 1;
$HLOCUpDown = 2;

$DiamondPointer = 0;
$TriangularPointer = 1;
$ArrowPointer = 2;
$ArrowPointer2 = 3;
$LinePointer = 4;
$PencilPointer = 5;

$ChartBackZ = 0x100;
$ChartFrontZ = 0xffff;
$PlotAreaZ = 0x1000;
$GridLinesZ = 0x2000;

$XAxisSymmetric = 1;
$XAxisSymmetricIfNeeded = 2;
$YAxisSymmetric = 4;
$YAxisSymmetricIfNeeded = 8;
$XYAxisSymmetric = 16;
$XYAxisSymmetricIfNeeded = 32;

$XAxisAtOrigin = 1;
$YAxisAtOrigin = 2;
$XYAxisAtOrigin = 3;
	
$NoValue = 1.7e308;
$LogTick = 1.6e308;
$LinearTick = 1.5e308;
$TickInc = 1.0e200;
$MinorTickOnly = -1.7e308;
$MicroTickOnly = -1.6e308;
$TouchBar = -1.7E-100;
$AutoGrid = -2;

$NoAntiAlias = 0;
$AntiAlias = 1;
$AutoAntiAlias = 2;

$TryPalette = 0;
$ForcePalette = 1;
$NoPalette = 2;
$Quantize = 0;
$OrderedDither = 1;
$ErrorDiffusion = 2;

$BoxFilter = 0;
$LinearFilter = 1;
$QuadraticFilter = 2;
$BSplineFilter = 3;
$HermiteFilter = 4;
$CatromFilter = 5;
$MitchellFilter = 6;
$SincFilter = 7;
$LanczosFilter = 8;
$GaussianFilter = 9;
$HanningFilter = 10;
$HammingFilter = 11;
$BlackmanFilter = 12;
$BesselFilter = 13;

$PNG = 0;
$GIF = 1;
$JPG = 2;
$WMP = 3;
$BMP = 4;
$SVG = 5;
$SVGZ = 6;

$Overlay = 0;
$Stack = 1;
$Depth = 2;
$Side = 3;
$Percentage = 4;

$defaultPalette = [
	0xffffff, 0x000000, 0x000000, 0x808080, 
	0x808080, 0x808080, 0x808080, 0x808080,
	0xff3333, 0x33ff33, 0x6666ff, 0xffff00, 
	0xff66ff, 0x99ffff,	0xffcc33, 0xcccccc, 
	0xcc9999, 0x339966, 0x999900, 0xcc3300,	
	0x669999, 0x993333, 0x006600, 0x990099,
	0xff9966, 0x99ff99, 0x9999ff, 0xcc6600,
	0x33cc33, 0xcc99ff, 0xff6666, 0x99cc66,
	0x009999, 0xcc3333, 0x9933ff, 0xff0000,
	0x0000ff, 0x00ff00, 0xffcc99, 0x999999,
	-1
];
$whiteOnBlackPalette = [
	0x000000, 0xffffff, 0xffffff, 0x808080, 
	0x808080, 0x808080, 0x808080, 0x808080,
	0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 
	0xff00ff, 0x66ffff,	0xffcc33, 0xcccccc, 
	0x9966ff, 0x339966, 0x999900, 0xcc3300,	
	0x99cccc, 0x006600, 0x660066, 0xcc9999,
	0xff9966, 0x99ff99, 0x9999ff, 0xcc6600,
	0x33cc33, 0xcc99ff, 0xff6666, 0x99cc66,
	0x009999, 0xcc3333, 0x9933ff, 0xff0000,
	0x0000ff, 0x00ff00, 0xffcc99, 0x999999,
	-1
];
$transparentPalette = [ 
	0xffffff, 0x000000, 0x000000, 0x808080, 
	0x808080, 0x808080, 0x808080, 0x808080,
	0x80ff0000, 0x8000ff00, 0x800000ff, 0x80ffff00, 
	0x80ff00ff, 0x8066ffff,	0x80ffcc33, 0x80cccccc, 
	0x809966ff, 0x80339966, 0x80999900, 0x80cc3300,
	0x8099cccc, 0x80006600, 0x80660066, 0x80cc9999,
	0x80ff9966, 0x8099ff99, 0x809999ff, 0x80cc6600,
	0x8033cc33, 0x80cc99ff, 0x80ff6666, 0x8099cc66,
	0x80009999, 0x80cc3333, 0x809933ff, 0x80ff0000,
	0x800000ff, 0x8000ff00, 0x80ffcc99, 0x80999999,
	-1
];

$NoSymbol = 0;
$SquareSymbol = 1;
$DiamondSymbol = 2;
$TriangleSymbol = 3;
$RightTriangleSymbol = 4;
$LeftTriangleSymbol = 5;
$InvertedTriangleSymbol = 6;
$CircleSymbol = 7;
$CrossSymbol = 8;
$Cross2Symbol = 9;
$PolygonSymbol = 11;
$Polygon2Symbol = 12;
$StarSymbol = 13;
$CustomSymbol = 14 ;

$NoShape = 0;
$SquareShape = 1;
$DiamondShape = 2;
$TriangleShape = 3;
$RightTriangleShape = 4;
$LeftTriangleShape = 5;
$InvertedTriangleShape = 6;
$CircleShape = 7;
$CircleShapeNoShading = 10;
$GlassSphereShape = 15;
$GlassSphere2Shape = 16;
$SolidSphereShape = 17;

sub cdBound
{
	my ($a, $b, $c) = @_;
	if ($b < $a) { return $a; }
	if ($b > $c) { return $c; }
	return $b;
}
sub CrossShape
{
	return $CrossSymbol | (int(cdBound(0, (defined $_[0]) ? $_[0] : 0.5, 1) * 4095 + 0.5) << 12);
}
sub Cross2Shape
{
	return $Cross2Symbol | (int(cdBound(0, (defined $_[0]) ? $_[0] : 0.5, 1) * 4095 + 0.5) << 12);
}
sub PolygonShape
{
	return $PolygonSymbol | (cdBound(0, $_[0], 100) << 12);
}
sub Polygon2Shape
{
	return $Polygon2Symbol | (cdBound(0, $_[0], 100) << 12);
}
sub StarShape
{
	return $StarSymbol | (cdBound(0, $_[0], 100) << 12);
}

$DashLine = 0x0505;
$DotLine = 0x0202;
$DotDashLine = 0x05050205;
$AltDashLine = 0x0A050505;

$goldGradient = [0, 0xFFE743, 0x60, 0xFFFFE0, 0xB0, 0xFFF0B0, 0x100, 0xFFE743];
$silverGradient = [0, 0xC8C8C8, 0x60, 0xF8F8F8, 0xB0, 0xE0E0E0, 0x100, 0xC8C8C8];
$redMetalGradient = [0, 0xE09898, 0x60, 0xFFF0F0, 0xB0, 0xF0D8D8, 0x100, 0xE09898];
$blueMetalGradient = [0, 0x9898E0, 0x60, 0xF0F0FF, 0xB0, 0xD8D8F0, 0x100, 0x9898E0];
$greenMetalGradient = [0, 0x98E098, 0x60, 0xF0FFF0, 0xB0, 0xD8F0D8, 0x100, 0x98E098];

sub metalColor
{
	return _f("metalColor", \@_, 2, 90);
}
sub goldColor
{
	return metalColor(0xffee44, @_);
}
sub silverColor
{
	return metalColor(0xdddddd, @_);
}
sub brushedMetalColor
{
	my $ret = eval {
		my ($c, $texture, $angle) = @{perlchartdir::checkarg(\@_, 3, 2, 90)};
		return int((metalColor($c, $angle) | (($texture & 0x3) << 18)));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $ret;
}
sub brushedSilverColor
{
	return brushedMetalColor(0xdddddd, @_);
}
sub brushedGoldColor
{
	return brushedMetalColor(0xffee44, @_);
}

$NormalLegend = 0;
$ReverseLegend = 1;
$NoLegend = 2;

$SideLayout = 0;
$CircleLayout = 1;

$PixelScale = 0;
$XAxisScale = 1;
$YAxisScale = 2;
$EndPoints = 3;
$AngularAxisScale = $XAxisScale;
$RadialAxisScale = $YAxisScale;

$MonotonicNone = 0; 
$MonotonicX = 1;
$MonotonicY = 2;
$MonotonicXY = 3;
$MonotonicAuto = 4;

$ConstrainedLinearRegression = 0;
$LinearRegression = 1;
$ExponentialRegression = -1;
$LogarithmicRegression = -2;

sub PolynomialRegression
{
	return shift;
}

$SmoothShading = 0;
$TriangularShading = 1;
$RectangularShading = 2;
$TriangularFrame = 3;
$RectangularFrame = 4;

$StartOfHourFilterTag = 1;
$StartOfDayFilterTag = 2;
$StartOfWeekFilterTag = 3;
$StartOfMonthFilterTag = 4;
$StartOfYearFilterTag = 5;
$RegularSpacingFilterTag = 6;
$AllPassFilterTag = 7;
$NonePassFilterTag = 8;
$SelectItemFilterTag = 9;

sub encodeFilter
{
	return _f("encodeFilter", \@_, 3, 1, 0.05);
}
sub StartOfHourFilter
{
	encodeFilter($StartOfHourFilterTag, @_);
}
sub StartOfDayFilter
{
	encodeFilter($StartOfDayFilterTag, @_);
}
sub StartOfWeekFilter
{
	encodeFilter($StartOfWeekFilterTag, @_);
}
sub StartOfMonthFilter
{
	encodeFilter($StartOfMonthFilterTag, @_);
}
sub StartOfYearFilter
{
	encodeFilter($StartOfYearFilterTag, @_);
}
sub RegularSpacingFilter
{
	my @arg = @_;
	if (!defined $arg[0]) { $arg[0] = 1; }
	$arg[1] = (defined $arg[1]) ? $arg[1] / 4095.0 : 0;
	encodeFilter($RegularSpacingFilterTag, @arg);
}
sub AllPassFilter
{
	encodeFilter($AllPassFilterTag, 0, 0);
}
sub NonePassFilter
{
	encodeFilter($NonePassFilterTag, 0, 0);
}
sub SelectItemFilter
{
	encodeFilter($SelectItemFilterTag, $_[0], 0);
}

$NormalGlare = 3;
$ReducedGlare = 2;
$NoGlare = 1;

sub glassEffect
{
	return _f("glassEffect", \@_, 3, $NormalGlare, $Top, 5);
}
sub softLighting
{
	return _f("softLighting", \@_, 2, $Top, 4);
}
sub barLighting
{
	return _f("barLighting", \@_, 2, 0.75, 1.5);	
}
sub cylinderEffect
{
	return _f("cylinderEffect", \@_, 5, $Center, 0.5, 0.5, 0.75, 8);
}

$DefaultShading = 0;
$FlatShading = 1;
$LocalGradientShading = 2;
$GlobalGradientShading = 3;
$ConcaveShading = 4;
$RoundedEdgeNoGlareShading = 5;
$RoundedEdgeShading = 6;
$RadialShading = 7;
$RingShading = 8;

$AggregateSum = 0;
$AggregateAvg = 1;
$AggregateStdDev = 2;
$AggregateMin = 3;
$AggregateMed = 4;
$AggregateMax = 5;
$AggregatePercentile = 6;
$AggregateFirst = 7;
$AggregateLast = 8;
$AggregateCount = 9;

$MouseUsageDefault = 0;
$MouseUsageScroll = 2;
$MouseUsageZoomIn = 3;
$MouseUsageZoomOut = 4;
	
$DirectionHorizontal = 0;
$DirectionVertical = 1;
$DirectionHorizontalVertical = 2;

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to libgraphics.h
#///////////////////////////////////////////////////////////////////////////////////
package CDAutoMethod;

sub new
{
	my ($class, $this) = @_;
	my $self = {};
	$self->{"this"} = $this;
	return bless($self, $class);
}
sub DESTROY
{
}
sub AUTOLOAD 
{	
	return perlchartdir::_r($AUTOLOAD, \@_); 
}  

package TTFText;
@ISA = ("CDAutoMethod");

#obsoleted constants - for compatibility only
$NoAntiAlias = $perlchartdir::NoAntiAlias;
$AntiAlias = $perlchartdir::AntiAlias;
$AutoAntiAlias = $perlchartdir::AutoAntiAlias;

$defaultArgs = {
	"draw"=>[undef, 4, $perlchartdir::TopLeft],
};

sub new
{
	my ($class, $this, $parent) = @_;
	my $self = {};
	$self->{"this"} = $this;
	$self->{"parent"} = $parent;
	return bless($self, $class);
}
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("TTFText.destroy", $self->{"this"})
}

package DrawArea;
@ISA = ("CDAutoMethod");

#obsoleted constants - for compatibility only
$TryPalette = $perlchartdir::TryPalette;
$ForcePalette = $perlchartdir::ForcePalette;
$NoPalette = $perlchartdir::NoPalette;
$Quantize = $perlchartdir::Quantize;
$OrderedDither = $perlchartdir::OrderedDither;
$ErrorDiffusion = $perlchartdir::ErrorDiffusion;

$defaultArgs = {
	"setSize"=>[undef, 3, 0xffffff],
	"resize"=>[undef, 4, $perlchartdir::LinearFilter, 1],
	"move"=>[undef, 5, 0xffffff, $perlchartdir::LinearFilter, 1],
	"rotate"=>[undef, 6, 0xffffff, -1, -1, $perlchartdir::LinearFilter, 1],
	"line"=>[undef, 6, 1],
	"rect"=>[undef, 7, 0],
	"text2"=>[undef, 11, $perlchartdir::TopLeft],
	"rAffineTransform"=>[undef, 9, 0xffffff, $perlchartdir::LinearFilter, 1],
	"affineTransform"=>[undef, 9, 0xffffff, $perlchartdir::LinearFilter, 1],
	"sphereTransform"=>[undef, 5, 0xffffff, $perlchartdir::LinearFilter, 1],
	"hCylinderTransform"=>[undef, 4, 0xffffff, $perlchartdir::LinearFilter, 1],
	"vCylinderTransform"=>[undef, 4, 0xffffff, $perlchartdir::LinearFilter, 1],
	"vTriangleTransform"=>[undef, 4, -1, 0xffffff, $perlchartdir::LinearFilter, 1],
	"hTriangleTransform"=>[undef, 4, -1, 0xffffff, $perlchartdir::LinearFilter, 1],
	"shearTransform"=>[undef, 5, 0, 0xffffff, $perlchartdir::LinearFilter, 1],
	"waveTransform"=>[undef, 8, 0, 0, 0, 0xffffff, $perlchartdir::LinearFilter, 1],
	"outJPG"=>[undef, 2, 80],
	"outSVG"=>[undef, 2, ""],
	"outJPG2"=>[undef, 1, 80],
	"outSVG2"=>[undef, 1, ""],
	"setAntiAlias"=>[undef, 2, 1, $perlchartdir::AutoAntiAlias],
	"dashLineColor"=>[undef, 2, $perlchartdir::DashLine],
	"patternColor2"=>[undef, 3, 0, 0],
	"gradientColor2"=>[undef, 5, 90, 1, 0, 0],
	"setDefaultFonts"=>[undef, 4, "", "", ""],
	"reduceColors"=>[undef, 2, 0],
	"linearGradientColor"=>[undef, 7, 0],
	"linearGradientColor2"=>[undef, 6, 0],
	"radialGradientColor"=>[undef, 7, 0],
	"radialGradientColor2"=>[undef, 6, 0]
};

sub new
{
	my ($class, $this) = @_;
	my $self = {};
	if (not $this)
	{
		$self->{"this"} = perlchartdir::callMethod("DrawArea.create");
		$self->{"own_this"} = 1;
	}
	else
	{
		$self->{"this"} = $this;
		$self->{"own_this"} = 0;
	}
	return bless($self, $class);
}
sub DESTROY
{
	my $self = shift;
	if ($self->{"own_this"})
		{ perlchartdir::callMethod("DrawArea.destroy", $self->{"this"}); }
}
sub clone
{
	my $ret = eval {
		my ($self, $d, $x, $y, $align, $newWidth, $newHeight, $ft, $blur) = @{perlchartdir::checkarg(\@_, 9,
			-1, -1, $perlchartdir::LinearFilter, 1)};
		perlchartdir::callMethod("DrawArea.clone", $self->{"this"}, $d->{"this"}, $x, $y, 
			$align, $newWidth, $newHeight, $ft, $blur);
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub polygon
{
	my $ret = eval {
		my ($self, $points, $edgeColor, $fillColor) = @{perlchartdir::checkarg(\@_, 4)};
		my @x = ();
		my @y = ();
		foreach my $p (@$points)
		{
			push(@x, $$p[0]);
			push(@y, $$p[1]);
		}
		perlchartdir::callMethod("DrawArea.polygon", $self->{"this"}, \@x, \@y, 
			$edgeColor, $fillColor);
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub fill
{
	if (scalar(@_) > 4) { shift()->fill2(@_); }
	else { perlchartdir::_m("DrawArea.fill", \@_, 3); }
}
sub text3
{
	my $self = $_[0];
	return new TTFText(perlchartdir::_m("DrawArea.text3", \@_, 3), $self);
}
sub text4
{
	my $self = $_[0];
	return new TTFText(perlchartdir::_m("DrawArea.text4", \@_, 7), $self);
}
sub merge
{
	my $ret = eval {
		my ($self, $d, $x, $y, $align, $transparency) = @{perlchartdir::checkarg(\@_, 6)};
		perlchartdir::callMethod("DrawArea.merge", $self->{"this"}, $d->{"this"}, $x, $y, 
			$align, $transparency);
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub tile
{
	my $ret = eval {
		my ($self, $d, $transparency) = @{perlchartdir::checkarg(\@_, 3)};
		perlchartdir::callMethod("DrawArea.tile", $self->{"this"}, $d->{"this"}, $transparency);
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub patternColor
{
	if (scalar(@_) < 3 or not ref($_[1])) { return shift()->patternColor2(@_); }
	return perlchartdir::_m("DrawArea.patternColor", \@_, 4, 0, 0);
}
sub gradientColor
{
	if (scalar(@_) < 7) { return shift()->gradientColor2(@_); }
	return perlchartdir::_m("DrawArea.gradientColor", \@_, 6);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to drawobj.h
#///////////////////////////////////////////////////////////////////////////////////
package Box;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setBackground"=>[undef, 3, -1, 0],
	"getImageCoor"=>[undef, 2, 0, 0],
	"setRoundedCorners"=>[undef, 4, 10, -1, -1, -1]
};
	
package TextBox;
@ISA = ("Box");

$defaultArgs = {
	"setFontStyle"=>[undef, 2, 0],
	"setFontSize"=>[undef, 2, 0],
	"setFontAngle"=>[undef, 2, 0],
	"setTruncate"=>[undef, 2, 1] 
};

package Line;
@ISA = ("CDAutoMethod");

package CDMLTable;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setPos"=>[undef, 3, $perlchartdir::TopLeft],
	"insertCol"=>["TextBox", 1],
	"appendCol"=>["TextBox", 0],
	"insertRow"=>["TextBox", 1],
	"appendRow"=>["TextBox", 0],
	"setText"=>["TextBox", 3],
	"setCell"=>["TextBox", 5],
	"getCell"=>["TextBox", 2],
	"getColStyle"=>["TextBox", 1],
	"getRowStyle"=>["TextBox", 1],
	"getStyle"=>["TextBox", 0]
};

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to basechart.h
#///////////////////////////////////////////////////////////////////////////////////
package LegendBox;
@ISA = ("TextBox");

$defaultArgs = {
	"setKeySize"=>[undef, 3, -1, -1],
	"setKeySpacing"=>[undef, 2, -1],
	"setKeyBorder"=>[undef, 2, 0],
	"setReverse"=>[undef, 1, 1],
	"setLineStyleKey"=>[undef, 1, 1],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0]		
};

sub addKey
{
	my $ret = eval {
		my ($self, $text, $color, $lineWidth, $drawarea) = @{perlchartdir::checkarg(\@_, 5, 0, undef)};
		perlchartdir::callMethod("LegendBox.addKey", $self->{"this"}, $text, $color, $lineWidth, perlchartdir::decodePtr($drawarea));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub addKey2
{
	my $ret = eval {
		my ($self, $zpos, $text, $color, $lineWidth, $drawarea) = @{perlchartdir::checkarg(\@_, 6, 0, undef)};
		perlchartdir::callMethod("LegendBox.addKey2", $self->{"this"}, $zpos, $text, $color, $lineWidth, perlchartdir::decodePtr($drawarea));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub getImageCoor2
{
	return perlchartdir::_m("LegendBox.getImageCoor", \@_, 3, 0, 0);
}

package BaseChart;
@ISA = ("CDAutoMethod");

#obsoleted - for compatibility only.
$PNG = $perlchartdir::PNG;
$GIF = $perlchartdir::GIF;
$JPG = $perlchartdir::JPG;
$WMP = $perlchartdir::WMP;

$defaultArgs = {
	"setBackground"=>[undef, 3, -1, 0],
	"setBgImage"=>[undef, 2, $perlchartdir::Center],
	"setDropShadow"=>[undef, 4, 0xaaaaaa, 5, 0x7fffffff, 5],
	"setAntiAlias"=>[undef, 2, 1, $perlchartdir::AutoAntiAlias],
	"addTitle2"=>["TextBox", 7, "", 12, $perlchartdir::TextColor, $perlchartdir::Transparent, $perlchartdir::Transparent],
	"addTitle"=>["TextBox", 6, "", 12, $perlchartdir::TextColor, $perlchartdir::Transparent, $perlchartdir::Transparent],
	"addLegend"=>["LegendBox", 5, 1, "", 10],
	"addLegend2"=>["LegendBox", 5, 1, "", 10],
	"getLegend"=>["LegendBox", 0],
	"layoutLegend"=>["LegendBox", 0],
	"getDrawArea"=>["DrawArea", 0],
	"addText"=>["TextBox", 9, "", 8, $perlchartdir::TextColor, $perlchartdir::TopLeft, 0, 0],
	"addLine"=>["Line", 6, $perlchartdir::LineColor, 1],
	"addTable"=>["CDMLTable", 5],
	"dashLineColor"=>[undef, 2, $perlchartdir::DashLine],
	"patternColor2"=>[undef, 3, 0, 0],
	"gradientColor2"=>[undef, 5, 90, 1, 0, 0],
	"setDefaultFonts"=>[undef, 4, "", "", ""],
	"setNumberFormat"=>[undef, 3, "~", ".", "-"],
	"makeChart3"=>["DrawArea", 0],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0],
	"setRoundedFrame"=>[undef, 5, 0xffffff, 10, -1, -1, -1],
	"linearGradientColor"=>[undef, 7, 0],
	"linearGradientColor2"=>[undef, 6, 0],
	"radialGradientColor"=>[undef, 7, 0],
	"radialGradientColor2"=>[undef, 6, 0]
};
	
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("BaseChart.destroy", $self->{"this"})
}
sub addDrawObj
{
	my $ret = eval {
		my ($self, $obj) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("BaseChart.addDrawObj", $self->{"this"}, $obj->{"this"});
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $obj;
}
sub patternColor
{
	if (scalar(@_) < 3 or not ref($_[1])) { return shift()->patternColor2(@_); }
	return perlchartdir::_m("BaseChart.patternColor", \@_, 4, 0, 0);
}
sub gradientColor
{
	if (scalar(@_) < 7) { return shift()->gradientColor2(@_); }
	return perlchartdir::_m("BaseChart.gradientColor", \@_, 6);
}
sub makeTmpFile
{
	my $self = shift;
	my $path = shift;
	my $imageFormat = (shift or $perlchartdir::PNG);
	my $lifeTime = (shift or 600);
	
	#remove trailing slashes
	$path =~ s/[\\\/]*$//;
	
	if ($imageFormat == $perlchartdir::JPG) { $imageFormat = "jpg"; }
	elsif ($imageFormat == $perlchartdir::GIF) { $imageFormat = "gif"; }
	elsif ($imageFormat == $perlchartdir::BMP) { $imageFormat = "bmp"; }
	elsif ($imageFormat == $perlchartdir::WMP) { $imageFormat = "wbmp"; }
	elsif ($imageFormat == $perlchartdir::SVG) { $imageFormat = "svg"; }
	elsif ($imageFormat == $perlchartdir::SVGZ) { $imageFormat = "svgz"; }
	else { $imageFormat = "png"; }
	
	my $filename = perlchartdir::tmpFile2($path, $lifeTime, ".$imageFormat");
	if ($self->makeChart("$path/$filename")) {
		return $filename;
	}
	else {
		return "";
	}
}

package MultiChart;
@ISA = ("BaseChart");

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("MultiChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	$self->{"dependencies"} = [];
	return bless($self, $class);
}
sub addChart
{
	my $ret = eval {
		my ($self, $x, $y, $c) = @{perlchartdir::checkarg(\@_, 4)};
		perlchartdir::callMethod("MultiChart.addChart", $self->{"this"}, $x, $y, $c->{"this"});
		push @{$self->{"dependencies"}}, $c;
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }		
}
sub setMainChart
{
	my $ret = eval {
		my ($self, $c) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("MultiChart.setMainChart", $self->{"this"}, $c->{"this"});
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to piechart.h
#///////////////////////////////////////////////////////////////////////////////////
package Sector;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setExplode"=>[undef, 1, -1],
	"setLabelStyle"=>["TextBox", 3, "", 8, $perlchartdir::TextColor],
	"setLabelPos"=>[undef, 2, -1],
	"setLabelLayout"=>[undef, 2, -1],
	"setJoinLine"=>[undef, 2, 1],
	"setColor"=>[undef, 3, -1, -1],
	"setStyle"=>[undef, 3, -1, -1],
	"getImageCoor"=>[undef, 2, 0, 0],
	"getLabelCoor"=>[undef, 2, 0, 0]
};

package PieChart;
@ISA = ("BaseChart");

$defaultArgs = {
	"setStartAngle"=>[undef, 2, 1],
	"setExplode"=>[undef, 2, -1, -1],
	"setExplodeGroup"=>[undef, 3, -1],
	"setLabelStyle"=>["TextBox", 3, "", 8, $perlchartdir::TextColor],
	"setLabelPos"=>[undef, 2, -1],
	"setLabelLayout"=>[undef, 4, -1, -1, -1],
	"setJoinLine"=>[undef, 2, 1],
	"setLineColor"=>[undef, 2, -1],
	"setSectorStyle"=>[undef, 3, -1, -1],
	"setData"=>[undef, 2, undef],
	"sector"=>["Sector", 1],
	"set3D2"=>[undef, 3, -1, 0]
};
	
sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("PieChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}
sub setPieSize
{
	perlchartdir::_m("PieChart.setPieSize", \@_, 3);
}
sub set3D
{
	perlchartdir::_m(perlchartdir::encodeIfArray("PieChart.set3D", $_[1]), \@_, 3, -1, -1, 0);
}
sub getSector
{
	return sector(@_);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to axis.h
#///////////////////////////////////////////////////////////////////////////////////
package Mark;
@ISA = ("TextBox");

sub setMarkColor
{
	perlchartdir::_m("Mark.setMarkColor", \@_, 3, -1, -1);
}

package Axis;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"setTitle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor],
	"setTitlePos"=>[undef, 2, 3],
	"setColors"=>[undef, 4, $perlchartdir::TextColor, -1, -1],
	"setTickWidth"=>[undef, 2, -1],
	"setTickColor"=>[undef, 2, -1],
	"setPos"=>[undef, 3, $perlchartdir::Center],
	"setMargin"=>[undef, 2, 0],
	"setAutoScale"=>[undef, 3, 0.1, 0.1, 0.8],
	"setTickDensity"=>[undef, 2, -1],
	"setReverse"=>[undef, 1, 1],
	"setLabels2"=>["TextBox", 2, ""],
	"makeLabelTable"=>["CDMLTable", 0],
	"getLabelTable"=>["CDMLTable", 0],
	"setLinearScale3"=>[undef, 1, ""],
	"setDateScale3"=>[undef, 1, ""],
	"addMark"=>["Mark", 5, "", "", 8],
	"addLabel2"=>[undef, 3, 0],
	"getAxisImageMap"=>[undef, 7, "", "", 0, 0],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0],
	"setMultiFormat2"=>[undef, 4, 1, 1],
	"setLabelStep"=>[undef, 4, 0, 0, -0x7fffffff],
	"setFormatCondition"=>[undef, 2, 0]
};

sub setTickLength
{
	if (scalar(@_) == 3) { shift()->setTickLength2(@_); }
	else { perlchartdir::_m("Axis.setTickLength", \@_, 1); }
}
sub setTopMargin
{
	shift()->setMargin(@_);
}
sub setLabels
{
	if (scalar(@_) < 3) {
		return new TextBox(perlchartdir::_m("Axis.setLabels", \@_, 1));
	} else {
		return shift()->setLabels2(@_);	
	}
}
sub setLinearScale
{
	if (scalar(@_) < 3) { shift()->setLinearScale3(@_); } 
	elsif (ref($_[3])) { shift()->setLinearScale2(@_); }
	else { perlchartdir::_m("Axis.setLinearScale", \@_, 4, 0, 0); }
}
sub setLogScale
{
	if (scalar(@_) < 3) { shift()->setLogScale3(@_); }
	elsif (ref($_[3])) { shift()->setLogScale2(@_); }
	else { perlchartdir::_m("Axis.setLogScale", \@_, 4, 0, 0); }
}
sub setLogScale2
{
	if (ref($_[3])) {
		perlchartdir::_m("Axis.setLogScale2", \@_, 3);
	} else {
		#compatibility with ChartDirector Ver 2.5
		shift()->setLogScale(@_);
	}	
}
sub setLogScale3
{
	if (($_[1]) && ($_[1] =~ m/^-?\d+$/)) {
		#compatibility with ChartDirector Ver 2.5
		if ($_[1]) { $_[0]->setLogScale3(); }
		else { $_[0]->setLinearScale3(); }
	} else {
		perlchartdir::_m("Axis.setLogScale3", \@_, 1, "");
	}
}
sub setDateScale
{
	if (scalar(@_) < 3) { shift()->setDateScale3(@_); }
	elsif (ref($_[3])) { shift()->setDateScale2(@_); }
	else { perlchartdir::_m("Axis.setDateScale", \@_, 4, 0, 0); }
}
sub syncAxis
{
	my $ret = eval {
		my ($self, $axis, $slope, $intercept) = @{perlchartdir::checkarg(\@_, 4, 1, 0)};
		perlchartdir::callMethod("Axis.syncAxis", $self->{"this"}, $axis->{"this"}, $slope, $intercept);
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub copyAxis
{
	my $ret = eval {
		my ($self, $axis) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("Axis.copyAxis", $self->{"this"}, $axis->{"this"});
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub setMultiFormat
{
	my $ret = eval {
		my ($self, $filter1, $format1, $filter2, $format2, $labelSpan, $promptFirst) = @{perlchartdir::checkarg(\@_, 7,
			1, undef, 1, 1)};
		if (!defined $format2) {
			$self->setMultiFormat2($filter1, $format1, $filter2, 1);
		} else {
			perlchartdir::callMethod("Axis.setMultiFormat", $self->{"this"}, $filter1, $format1, $filter2, $format2, $labelSpan, $promptFirst);
		}
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }	
}

package ColorAxis;
@ISA = ("Axis");

$defaultArgs = {
	"setColorGradient"=>[undef, 4, 1, undef, -1, -1],
	"setCompactAxis"=>[undef, 1, 1],
	"setAxisBorder"=>[undef, 2, 0],
	"setBoundingBox"=>[undef, 3, $perlchartdir::Transparent, 0],
	"setRoundedCorners"=>[undef, 4, 10, -1, -1, -1]
};

package AngularAxis;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"setReverse"=>[undef, 1, 1],
	"setLabels2"=>["TextBox", 2, ""],
	"addZone2"=>[undef, 4, -1],
	"getAxisImageMap"=>[undef, 7, "", "", 0, 0],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0]
};

sub setLabels
{
	if (scalar(@_) < 3) { return new TextBox(perlchartdir::_m("AngularAxis.setLabels", \@_, 1)); } 
	else { return shift()->setLabels2(@_); }
}
sub setLinearScale
{
	if (ref($_[3])) { shift()->setLinearScale2(@_); } 
	else { perlchartdir::_m("AngularAxis.setLinearScale", \@_, 4, 0, 0); }
}
sub addZone
{
	if (scalar(@_) < 6) { shift()->addZone2(@_); } 
	else { perlchartdir::_m("AngularAxis.addZone", \@_, 6, -1); }
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to layer.h
#///////////////////////////////////////////////////////////////////////////////////
package DataSet;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setDataColor"=>[undef, 4, -1, -1, -1, -1],
	"setUseYAxis2"=>[undef, 1, 1],
	"setDataLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"setDataSymbol4"=>[undef, 4, 11, -1, -1]
};

sub setDataSymbol
{
	if ((scalar(@_) < 3) && ($_[1]) && ($_[1] !~ m/^\d+$/)) { shift()->setDataSymbol2(@_); } 
	else { perlchartdir::_m("DataSet.setDataSymbol", \@_, 5, 5, -1, -1, 1); }
}
sub setDataSymbol2
{
	if (ref($_[1])) { shift()->setDataSymbol3(@_); } 
	else { perlchartdir::_m("DataSet.setDataSymbol2", \@_, 1); }
}
sub setDataSymbol3
{
	my $ret = eval {
		my ($self, $d) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("DataSet.setDataSymbol3", $self->{"this"}, $d->{"this"});
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}	
sub setUseYAxis
{
	my $ret = eval {
		my ($self, $axis) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("DataSet.setUseYAxis", $self->{"this"}, $axis->{"this"});
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
	
package Layer;
@ISA = ("CDAutoMethod");

#obsoleted - for compatibility only
$Overlay = $perlchartdir::Overlay;
$Stack = $perlchartdir::Stack;
$Depth = $perlchartdir::Depth;
$Side = $perlchartdir::Side;

$defaultArgs = {
	"setBorderColor"=>[undef, 2, 0],
	"set3D"=>[undef, 2, -1, 0],
	"addDataSet"=>["DataSet", 3, -1, ""],
	"addDataGroup"=>[undef, 1, ""],
	"getDataSet"=>["DataSet", 1],
	"setUseYAxis2"=>[undef, 1, 1],
	"setLegendOrder"=>[undef, 2, -1],
	"setDataLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"setAggregateLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"addCustomDataLabel"=>["TextBox", 7, "", 8, $perlchartdir::TextColor, 0],
	"addCustomAggregateLabel"=>["TextBox", 6, "", 8, $perlchartdir::TextColor, 0],
	"addCustomGroupLabel"=>["TextBox", 7, "", 8, $perlchartdir::TextColor, 0],
	"getImageCoor2"=>[undef, 3, 0, 0],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0],
	"setHTMLImageMap"=>[undef, 3, "", ""]
};
	
sub getImageCoor
{
	if (scalar(@_) == 2) { return shift()->getImageCoor2(@_); }
	return perlchartdir::_m("Layer.getImageCoor", \@_, 4, 0, 0);
}
sub setXData
{
	if (scalar(@_) > 2) { shift()->setXData2(@_); }
	else { perlchartdir::_m("Layer.setXData", \@_, 1); }
}
sub getYCoor
{
	if (ref($_[2])) { 
		my $ret = eval {
			my ($self, $value, $yAxis) = @{perlchartdir::checkarg(\@_, 3)};
			return perlchartdir::callMethod("Layer.getYCoor2", $self->{"this"}, $value, $yAxis->{"this"});
		};
		if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
		return $ret;
	} else { 
		return perlchartdir::_m("Layer.getYCoor", \@_, 2, 1); 
	}
}
sub setUseYAxis
{
	my $ret = eval {
		my ($self, $axis) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("Layer.setUseYAxis", $self->{"this"}, $axis->{"this"});
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
sub yZoneColor
{
	if (ref($_[4])) { 
		my $ret = eval {
			my ($self, $threshold, $belowColor, $aboveColor, $yAxis) = @{perlchartdir::checkarg(\@_, 5)};
			return perlchartdir::callMethod("Layer.yZoneColor2", $self->{"this"}, $threshold, $belowColor, $aboveColor, $yAxis->{"this"});
		};
		if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
		return $ret;
	} 
	else { 
		return perlchartdir::_m("Layer.yZoneColor", \@_, 4, 1); 
	}
}
sub alignLayer
{
	my $ret = eval {
		my ($self, $layer, $dataSet) = @{perlchartdir::checkarg(\@_, 3)};
		perlchartdir::callMethod("Layer.alignLayer", $self->{"this"}, $layer->{"this"}, $dataSet);
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

sub moveFront
{
	my $ret = eval {
		my ($self, $layer) = @{perlchartdir::checkarg(\@_, 2, undef)};
		perlchartdir::callMethod("Layer.moveFront", $self->{"this"}, perlchartdir::decodePtr($layer));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

sub moveBack
{
	my $ret = eval {
		my ($self, $layer) = @{perlchartdir::checkarg(\@_, 2, undef)};
		perlchartdir::callMethod("Layer.moveBack", $self->{"this"}, perlchartdir::decodePtr($layer));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to barlayer.h
#///////////////////////////////////////////////////////////////////////////////////
package BarLayer;
@ISA = ("Layer");

$defaultArgs = {
	"setBarGap"=>[undef, 2, 0.2],
	"setBarWidth"=>[undef, 2, -1],
	"setIconSize"=>[undef, 2, -1],
	"setOverlapRatio"=>[undef, 2, 1],
	"setBarShape2"=>[undef, 3, -1, -1]
};

sub setBarShape
{
	perlchartdir::_m(perlchartdir::encodeIfArray("BarLayer.setBarShape", $_[1]), \@_, 3, -1, -1);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to linelayer.h
#///////////////////////////////////////////////////////////////////////////////////
package LineLayer;
@ISA = ("Layer");

$defaultArgs = {
	"setGapColor"=>[undef, 2, -1],
	"setSymbolScale"=>[undef, 4, $perlchartdir::PixelScale, undef, $perlchartdir::PixelScale],
	"getLine"=>[undef, 1, 0]
};

package ScatterLayer;
@ISA = ("LineLayer");

package InterLineLayer;
@ISA = ("LineLayer");

sub setGapColor
{
	perlchartdir::_m("InterLineLayer.setGapColor", \@_, 2, -1);
}

package SplineLayer;
@ISA = ("LineLayer");
	
package StepLineLayer;
@ISA = ("LineLayer");
	
#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to trendlayer.h
#///////////////////////////////////////////////////////////////////////////////////
package TrendLayer;
@ISA = ("Layer");

$defaultArgs = {
	"addConfidenceBand"=>[undef, 7, $perlchartdir::Transparent, 1, -1, -1, -1],
	"addPredictionBand"=>[undef, 7, $perlchartdir::Transparent, 1, -1, -1, -1]
};

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to arealayer.h
#///////////////////////////////////////////////////////////////////////////////////
package AreaLayer;
@ISA = ("Layer");

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to hloclayer.h
#///////////////////////////////////////////////////////////////////////////////////
package BaseBoxLayer;
@ISA = ("Layer");

package HLOCLayer;
@ISA = ("BaseBoxLayer");

sub setColorMethod
{
	perlchartdir::_m("HLOCLayer.setColorMethod", \@_, 4, -1, -1.7E308);
}
		
package CandleStickLayer;
@ISA = ("BaseBoxLayer");

package BoxWhiskerLayer;
@ISA = ("BaseBoxLayer");

$defaultArgs = {
	"setBoxColors"=>[undef, 2, undef],
	"addPredictionBand"=>[undef, 7, $perlchartdir::Transparent, 1, -1, -1, -1]
};

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to vectorlayer.h
#///////////////////////////////////////////////////////////////////////////////////
package VectorLayer;
@ISA = ("Layer");

$defaultArgs = {
	"setVector"=>[undef, 3, $perlchartdir::PixelScale],
	"setIconSize"=>[undef, 2, 0],
	"setVectorMargin"=>[undef, 2, $perlchartdir::NoValue]
};
	
sub setArrowHead
{
	if (ref($_[1])) { shift()->setArrowHead2(@_); }
	else { perlchartdir::_m("VectorLayer.setArrowHead", \@_, 2, 0); }
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to contourlayer.h
#///////////////////////////////////////////////////////////////////////////////////
package ContourLayer;
@ISA = ("Layer");

$defaultArgs = {
	"setContourColor"=>[undef, 2, -1],
	"setContourWidth"=>[undef, 2, -1],
	"setColorAxis"=>["ColorAxis", 5],
	"colorAxis"=>["ColorAxis", 0]
};	

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to xychart.h
#///////////////////////////////////////////////////////////////////////////////////
package PlotArea;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setBackground"=>[undef, 3, -1, -1],
	"setBackground2"=>[undef, 2, $perlchartdir::Center],
	"set4QBgColor"=>[undef, 5, -1],
	"setAltBgColor"=>[undef, 4, -1],
	"setGridColor"=>[undef, 4, $perlchartdir::Transparent, -1, -1],
	"setGridWidth"=>[undef, 4, -1, -1, -1]
};

sub setGridAxis
{
	my $ret = eval {
		my ($self, $xAxis, $yAxis) = @{perlchartdir::checkarg(\@_, 3)};
		perlchartdir::callMethod("PlotArea.setGridAxis", $self->{"this"}, perlchartdir::decodePtr($xAxis),
			perlchartdir::decodePtr($yAxis));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

sub moveGridBefore
{
	my $ret = eval {
		my ($self, $layer) = @{perlchartdir::checkarg(\@_, 2, undef)};
		perlchartdir::callMethod("PlotArea.moveGridBefore", $self->{"this"}, perlchartdir::decodePtr($layer));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}

package XYChart;
@ISA = ("BaseChart");

$defaultArgs = {
	"yAxis"=>["Axis", 0],	
	"yAxis2"=>["Axis", 0],	
	"syncYAxis"=>["Axis", 2, 1, 0],	
	"setYAxisOnRight"=>[undef, 1, 1],
	"setXAxisOnTop"=>[undef, 1, 1],
	"xAxis"=>["Axis", 0],	
	"xAxis2"=>["Axis", 0],	
	"addAxis"=>["Axis", 2],
	"swapXY"=>[undef, 1, 1],
	"setPlotArea"=>["PlotArea", 9, $perlchartdir::Transparent, -1, -1, 0xc0c0c0, $perlchartdir::Transparent],
	"getPlotArea"=>["PlotArea", 0],
	"setClipping"=>[undef, 1, 0],
	"addBarLayer2"=>["BarLayer", 2, $perlchartdir::Side, 0],
	"addBarLayer3"=>["BarLayer", 4, undef, undef, 0],
	"addLineLayer2"=>["LineLayer", 2, $perlchartdir::Overlay, 0],
	"addAreaLayer2"=>["AreaLayer", 2, $perlchartdir::Stack, 0],
	"addHLOCLayer2"=>["HLOCLayer", 0],
	"addScatterLayer"=>["ScatterLayer", 7, "", $perlchartdir::SquareSymbol, 5, -1, -1],
	"addCandleStickLayer"=>["CandleStickLayer", 7, 0xffffff, 0x0, $perlchartdir::LineColor],
	"addBoxWhiskerLayer"=>["BoxWhiskerLayer", 8, undef, undef, undef, -1, $perlchartdir::LineColor, $perlchartdir::LineColor],
	"addBoxWhiskerLayer2"=>["BoxWhiskerLayer", 8, undef, undef, undef, undef, 0.5, undef],
	"addBoxLayer"=>["BoxWhiskerLayer", 4, -1, ""],
	"addTrendLayer"=>["TrendLayer", 4, -1, "", 0],
	"addTrendLayer2"=>["TrendLayer", 5, -1, "", 0],
	"addSplineLayer"=>["SplineLayer", 3, undef, -1, ""],
	"addStepLineLayer"=>["StepLineLayer", 3, undef, -1, ""],
	"addInterLineLayer"=>["InterLineLayer", 4, -1],
	"addVectorLayer"=>["VectorLayer", 7, $perlchartdir::PixelScale, -1, ""],
	"addContourLayer"=>["ContourLayer", 3],
	"setAxisAtOrigin"=>[undef, 2, $perlchartdir::XYAxisAtOrigin, 0],
	"setTrimData"=>[undef, 2, 0x7fffffff],
	"packPlotArea"=>[undef, 6, 0, 0]
};
	
sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("XYChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}
sub addBarLayer
{
	if (scalar(@_) == 1) { return shift()->addBarLayer2(@_); }
	return new BarLayer(perlchartdir::_m("XYChart.addBarLayer", \@_, 4, -1, "", 0));
}
sub addLineLayer
{
	if (scalar(@_) == 1) { return shift()->addLineLayer2(@_); }
	return new LineLayer(perlchartdir::_m("XYChart.addLineLayer", \@_, 4, -1, "", 0));
}
sub addAreaLayer
{
	if (scalar(@_) == 1) { return shift()->addAreaLayer2(@_); }
	return new AreaLayer(perlchartdir::_m("XYChart.addAreaLayer", \@_, 4, -1, "", 0));
}
sub addHLOCLayer
{
	if (scalar(@_) == 1) { return shift()->addHLOCLayer2(@_); }
	return new HLOCLayer(perlchartdir::_m("XYChart.addHLOCLayer3", \@_, 8, undef, undef, -1, -1, -1, -1.7E308));
}
sub addHLOCLayer3
{
	return addHLOCLayer(@_);
}
sub getYCoor
{
	my $ret = eval {
		my ($self, $value, $yAxis) = @{perlchartdir::checkarg(\@_, 3, undef)};
		perlchartdir::callMethod("XYChart.getYCoor", $self->{"this"}, $value, perlchartdir::decodePtr($yAxis));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $ret;
}
sub yZoneColor
{
	my $ret = eval {
		my ($self, $threshold, $belowColor, $aboveColor, $yAxis) = @{perlchartdir::checkarg(\@_, 5, undef)};
		return perlchartdir::callMethod("XYChart.yZoneColor", $self->{"this"}, $threshold, $belowColor, $aboveColor, perlchartdir::decodePtr($yAxis));
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $ret;
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to surfacechart.h
#///////////////////////////////////////////////////////////////////////////////////
package SurfaceChart;
@ISA = ("BaseChart");

$defaultArgs = {
	"setViewAngle"=>[undef, 3, 0, 0],	
	"setInterpolation"=>[undef, 3, -1, 1],	
	"setShadingMode"=>[undef, 2, 1],	
	"setSurfaceAxisGrid"=>[undef, 4, -1, -1, -1],
	"setSurfaceDataGrid"=>[undef, 2, -1],
	"setContourColor"=>[undef, 2, -1],
	"xAxis"=>["Axis", 0],	
	"yAxis"=>["Axis", 0],
	"zAxis"=>["Axis", 0],	
	"setColorAxis"=>["ColorAxis", 5],	
	"colorAxis"=>["ColorAxis", 0],
	"setWallColor"=>[undef, 4, -1, -1, -1],
	"setWallThickness"=>[undef, 3, -1, -1],
	"setWallGrid"=>[undef, 6, -1, -1, -1, -1, -1]
};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("SurfaceChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to polarchart.h
#///////////////////////////////////////////////////////////////////////////////////
package PolarLayer;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setData"=>[undef, 3, -1, ""],
	"setSymbolScale"=>[undef, 2, $perlchartdir::PixelScale],
	"getImageCoor"=>[undef, 3, 0, 0],
	"getHTMLImageMap"=>[undef, 5, "", "", 0, 0],
	"setDataLabelStyle"=>["TextBox", 4, "", 8, $perlchartdir::TextColor, 0],
	"addCustomDataLabel"=>["TextBox", 6, "", 8, $perlchartdir::TextColor, 0],
	"setDataSymbol4"=>[undef, 4, 11, -1, -1],
	"setHTMLImageMap"=>[undef, 3, "", ""]
};

sub setDataSymbol
{
	if ((scalar(@_) < 3) && ($_[1]) && ($_[1] !~ m/^\d+$/)) { shift()->setDataSymbol2(@_); }
	else { perlchartdir::_m("PolarLayer.setDataSymbol", \@_, 5, 7, -1, -1, 1); }
}
sub setDataSymbol2
{
	if (ref($_[1])) { shift()->setDataSymbol3(@_); } 
	else { perlchartdir::_m("PolarLayer.setDataSymbol2", \@_, 1); }
}
sub setDataSymbol3
{
	my $ret = eval {
		my ($self, $d) = @{perlchartdir::checkarg(\@_, 2)};
		perlchartdir::callMethod("PolarLayer.setDataSymbol3", $self->{"this"}, $d->{"this"});
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
}
	
package PolarAreaLayer;
@ISA = ("PolarLayer");

package PolarLineLayer;
@ISA = ("PolarLayer");

$defaultArgs = {
	"setGapColor"=>[undef, 2, -1]
};

package PolarSplineLineLayer;
@ISA = ("PolarLineLayer");

package PolarSplineAreaLayer;
@ISA = ("PolarAreaLayer");

package PolarVectorLayer;
@ISA = ("PolarLayer");

$defaultArgs = {
	"setVector"=>[undef, 3, $perlchartdir::PixelScale],
	"setIconSize"=>[undef, 2, 0],
	"setVectorMargin"=>[undef, 2, $perlchartdir::NoValue]
};

sub setArrowHead
{
	if (ref($_[1])) { shift()->setArrowHead2(@_); }
	else { perlchartdir::_m("PolarVectorLayer.setArrowHead", \@_, 2, 0); }
}
	
package PolarChart;
@ISA = ("BaseChart");

$defaultArgs = {
	"setPlotArea"=>[undef, 6, $perlchartdir::Transparent, $perlchartdir::Transparent, 1],	
	"setPlotAreaBg"=>[undef, 3, -1, 1],	
	"setGridColor"=>[undef, 4, $perlchartdir::LineColor, 1, $perlchartdir::LineColor, 1],
	"setGridStyle"=>[undef, 2, 1],
	"setStartAngle"=>[undef, 2, 1],
	"angularAxis"=>["AngularAxis", 0],
	"radialAxis"=>["Axis", 0],	
	"addAreaLayer"=>["PolarAreaLayer", 3, -1, ""],
	"addLineLayer"=>["PolarLineLayer", 3, -1, ""],
	"addSplineLineLayer"=>["PolarSplineLineLayer", 3, -1, ""],
	"addSplineAreaLayer"=>["PolarSplineAreaLayer", 3, -1, ""],
	"addVectorLayer"=>["PolarVectorLayer", 7, $perlchartdir::PixelScale, -1, ""]
	};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("PolarChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to pyramidchart.h
#///////////////////////////////////////////////////////////////////////////////////
package PyramidLayer;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setCenterLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setRightLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setLeftLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setJoinLine"=>[undef, 2, -1],
	"setJoinLineGap"=>[undef, 3, -0x7fffffff, -0x7fffffff],
	"setLayerBorder"=>[undef, 2, -1]
};	

package PyramidChart;
@ISA = ("BaseChart");

$defaultArgs = {
	"setFunnelSize"=>[undef, 6, 0.2, 0.3],
	"setData"=>[undef, 2, undef],
	"setCenterLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setRightLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setLeftLabel"=>["TextBox", 4, "{skip}", "{skip}", -1, -1],
	"setViewAngle"=>[undef, 3, 0, 0],
	"setLighting"=>[undef, 4, 0.5, 0.5, 1, 8],
	"setJoinLine"=>[undef, 2, -1],
	"setJoinLineGap"=>[undef, 3, -0x7fffffff, -0x7fffffff],
	"setLayerBorder"=>[undef, 2, -1],
	"getLayer"=>["PyramidLayer", 1]
};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("PyramidChart.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to meters.h
#///////////////////////////////////////////////////////////////////////////////////
package MeterPointer;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setColor"=>[undef, 2, -1],
	"setShape2"=>[undef, 3, $perlchartdir::NoValue, $perlchartdir::NoValue]
};

sub setShape
{
	perlchartdir::_m(perlchartdir::encodeIfArray("MeterPointer.setShape", $_[1]), \@_, 3, $perlchartdir::NoValue, $perlchartdir::NoValue);
}
	
package BaseMeter;
@ISA = ("BaseChart");

$defaultArgs = {
	"addPointer"=>["MeterPointer", 3, $perlchartdir::LineColor, -1],
	"setScale3"=>[undef, 4, ""],
	"setLabelStyle"=>["TextBox", 4, "bold", -1, $perlchartdir::TextColor, 0],
	"setLabelPos"=>[undef, 2, 0],
	"setTickLength"=>[undef, 3, -0x7fffffff, -0x7fffffff],
	"setLineWidth"=>[undef, 4, 1, 1, 1],
	"setMeterColors"=>[undef, 3, -1, -1]
};

sub setScale
{
	if (ref($_[3])) {
		if (scalar(@_) >= 5) { shift()->setScale3(@_); }
		else { shift()->setScale2(@_); }
	} else {
		perlchartdir::_m("BaseMeter.setScale", \@_, 5, 0, 0, 0);
	}
}

package AngularMeter;
@ISA = ("BaseMeter");

$defaultArgs = {
	"addRing"=>[undef, 4, -1],
	"addRingSector"=>[undef, 6, -1],
	"setCap"=>[undef, 3, $perlchartdir::LineColor],
	"addZone2"=>[undef, 4, -1]
};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("AngularMeter.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}
sub addZone
{
	if (scalar(@_) < 6) { shift()->addZone2(@_); } 
	else { perlchartdir::_m("AngularMeter.addZone", \@_, 6, -1); }
}

package LinearMeter;
@ISA = ("BaseMeter");

$defaultArgs = {
	"setMeter"=>[undef, 6, $perlchartdir::Left, 0],
	"setRail"=>[undef, 3, 2, 6],
	"addZone"=>["TextBox", 4, ""]
};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("LinearMeter.create", \@_, 5, 
		$perlchartdir::BackgroundColor, $perlchartdir::Transparent, 0);
	return bless($self, $class);
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to chartdir.h
#///////////////////////////////////////////////////////////////////////////////////
package perlchartdir;

sub getCopyright
{
	return _f("getCopyright", \@_);
}
sub getVersion
{
	return _f("getVersion", \@_);
}
sub getDescription
{
	return _f("getDescription", \@_)
}
sub getBootLog
{
	return _f("getBootLog", \@_);
}
sub libgTTFTest
{
	return _f("testFont", \@_, 5, "", 0, 8, 8, 0);
}

sub testFont 
{
	return _f("testFont", \@_, 5, "", 0, 8, 8, 0);
}

sub setLicenseCode
{
	return _f("setLicenseCode", \@_, 1);
}

sub chartTime
{
	if (scalar(@_) < 3) { return chartTime2(@_); }
	return _f("chartTime", \@_, 6, 0, 0, 0);
}

sub chartTime2
{
	return _f("chartTime2", \@_, 1);
}

sub getChartYMD
{
	return _f("getChartYMD", \@_, 1);
}

sub getChartWeekDay
{
	return int($_[0] / 86400 + 1) % 7;
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to rantable.h
#///////////////////////////////////////////////////////////////////////////////////
package RanTable;
@ISA = ("CDAutoMethod");

$defaultArgs = {
	"setCol2"=>[undef, 6, -1E+308, 1E+308],
	"setDateCol"=>[undef, 4, 0],
	"setHLOCCols"=>[undef, 6, 0, 1E+308]
	};

sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("RanTable.create", \@_, 3);
	return bless($self, $class);
}
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("RanTable.destroy", $self->{"this"})
}
sub setCol
{
	if (defined($_[4])) { shift()->setCol2(@_);	} 
	else { perlchartdir::_m("RanTable.setCol", \@_, 3); }
}

package FinanceSimulator;
@ISA = ("CDAutoMethod");

sub new 
{
	my $class = shift;
	my $self = {};
	if ($_[0] !~ m/^[+-]?\d+$/) {
		$self->{"this"} = perlchartdir::_f("FinanceSimulator.create2", \@_, 4);
	} else {
		$self->{"this"} = perlchartdir::_f("FinanceSimulator.create", \@_, 4);
	}
	return bless($self, $class);
}
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("FinanceSimulator.destroy", $self->{"this"})
}

#///////////////////////////////////////////////////////////////////////////////////
#//	bindings to datafilter.h
#///////////////////////////////////////////////////////////////////////////////////
package ArrayMath;

$defaultArgs = {
	"shift"=>[undef, 2, 1, $perlchartdir::NoValue],
	"delta"=>[undef, 1, 1],
	"rate"=>[undef, 1, 1],
	"trim"=>[undef, 2, 0, -1],
	"insert"=>[undef, 2, -1],
	"insert2"=>[undef, 3, -1],
	"selectGTZ"=>[undef, 2, undef, 0],
	"selectGEZ"=>[undef, 2, undef, 0],
	"selectLTZ"=>[undef, 2, undef, 0],
	"selectLEZ"=>[undef, 2, undef, 0],
	"selectEQZ"=>[undef, 2, undef, 0],
	"selectNEZ"=>[undef, 2, undef, 0],
	"selectStartOfHour"=>[undef, 2, 1, 300],
	"selectStartOfDay"=>[undef, 2, 1, 3 * 3600],
	"selectStartOfWeek"=>[undef, 2, 1, 2 * 86400],
	"selectStartOfMonth"=>[undef, 2, 1, 5 * 86400],
	"selectStartOfYear"=>[undef, 2, 1, 60 * 86400],
	"movCorr"=>[undef, 2, undef],
	"lowess"=>[undef, 2, 0.25, 0],
	"lowess2"=>[undef, 3, 0.25, 0],
	"selectRegularSpacing"=>[undef, 3, 0, 0],
	"aggregate"=>[undef, 3, 50]
	};
	
sub new 
{
	my $class = shift;
	my $self = {};
	$self->{"this"} = perlchartdir::_f("ArrayMath.create", \@_, 1);
	return bless($self, $class);
}
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("ArrayMath.destroy", $self->{"this"})
}
sub AUTOLOAD 
{	
	my $self = $_[0];
	my $ret = perlchartdir::_r($AUTOLOAD, \@_); 
	if ($ret eq $self->{"this"}) { return $self; } 
	else { return $ret; }
}
sub binOp
{
	my ($self, $arg, $op) = @_;
	if (!ref($arg)) { $op .= "2"; }
	perlchartdir::_m("ArrayMath.$op", [$self, $arg], 1);
	return $self;
}
sub add 
{ 
	return binOp(@_, "add"); 
}
sub sub
{
	return binOp(@_, "sub");
}
sub mul
{
	return binOp(@_, "mul");
}
sub div
{
	return binOp(@_, "div");
}

#///////////////////////////////////////////////////////////////////////////////////
#//	Utility functions
#///////////////////////////////////////////////////////////////////////////////////
package perlchartdir;

sub tmpFile2 
{
	my ($path, $lifeTime, $ext) = @_;

	#avoid checking for old files too frequently
	if ($lifeTime >= 0)
	{
		my $currentTime = time;
		my $timeStampFile = "$path/__cd__lastcheck.tmp";
		if (-e $timeStampFile)
		{
			my $lastCheck = abs($currentTime - (stat($timeStampFile))[9]);
			if (($lastCheck < $lifeTime) && ($lastCheck < 10)) {
				$lifeTime = -1;
			} else {
				utime($currentTime, $currentTime, $timeStampFile);
			}
		}
		else
		{
			open(INFO, ">$timeStampFile");
			print INFO $currentTime;
			close(INFO);
		}
	}
	
	#remove old temporary files
	if ($lifeTime >= 0)
	{
		if (!opendir(DIR, $path)) {
			#make the directory from the root up in case it does not exist
			my @acc;
			for (split(/[\\\/]/, $path)) {
				push @acc, $_;
				mkdir(join("/", @acc), 0777);
			}
			opendir(DIR, $path) or return "$path/cannot_open_directory";	
		}
		unlink(map { ((substr($_, 0, 4) eq "cd__") && (abs(time - (stat("$path/$_"))[9]) > $lifeTime)) ? ("$path/$_" =~ /(.*)/) : () } readdir(DIR));
		closedir(DIR);
	}
	
	#create unique file name
	my $seqNo = 0;
	my $filename = "";
	while ($seqNo < 100)
	{
		if (exists $ENV{'UNIQUE_ID'}) {
			$filename = "cd__".$ENV{'UNIQUE_ID'}.time.'_'.$seqNo.$ext;
		} else {
			$filename = "cd__".$ENV{'REMOTE_ADDR'}.$ENV{'REMOTE_PORT'}.$$.time.'_'.$seqNo.$ext;
		}
		$filename =~ s/:/_/g;
		if (! -e "$path/$filename") {
			last;
		}
		$seqNo++;
	}
	return ($filename =~ /(.*)/)[0];
}

sub tmpFile
{
	#for compatibility with ChartDirector Ver 2.5
	my $path = (shift or "/tmp/tmp_charts");
	my $lifeTime = (shift or 600);
	#remove trailing slashes
	$path =~ s/[\\\/]*$//;
	return $path . "/" . perlchartdir::tmpFile2($path, $lifeTime, "");
}

#///////////////////////////////////////////////////////////////////////////////////
#//	WebChartViewer implementation
#///////////////////////////////////////////////////////////////////////////////////
package WebChartViewer;

$j_s = "_JsChartViewerState";
$j_p = "cdPartialUpdate";
$j_d = "cdDirectStream";

sub new 
{
	my ($class, $request, $id) = @_;
	my $self = {};
	$self->{"this"} = perlchartdir::callMethod("WebChartViewer.create");
	$self->{"request"} = $request;
	bless($self, $class);
	$self->putAttrS(":id", $id);
	if ((defined $request) && (defined $id) && (defined $request->param($id.$j_s))) {
		$self->putAttrS(":state", $request->param($id.$j_s));
	}
	return $self;
}
sub DESTROY
{
	my $self = shift;
	perlchartdir::callMethod("WebChartViewer.destroy", $self->{"this"})
}

sub getRequest { return $_[0]->{"request"}; }
sub getId { return $_[0]->getAttrS(":id"); }

sub setImageUrl { $_[0]->putAttrS(":url", $_[1]); }
sub getImageUrl { return $_[0]->getAttrS(":url"); }

sub setImageMap { $_[0]->putAttrS(":map", $_[1]); }
sub getImageMap { return $_[0]->getAttrS(":map"); }
	
sub setChartMetrics { $_[0]->putAttrS(":metrics", $_[1]); }
sub getChartMetrics { return $_[0]->getAttrS(":metrics"); }
	
sub makeDelayedMapAsTmpFile
{
	my $ret = eval {
		my ($self, $path, $imageMap, $compress, $timeout) = @{perlchartdir::checkarg(\@_, 5, 0, 600)};

		if ($compress)
		{
			if (!defined $ENV{'HTTP_ACCEPT_ENCODING'} || ($ENV{'HTTP_ACCEPT_ENCODING'} !~ /\bgzip\b/i))
			{
				$compress = 0;
			}
		}
		
		my $b = "<body><!--CD_MAP $imageMap CD_MAP--></body>";
		my $ext = ".map";
		if ($compress)
		{
			$b = perlchartdir::callMethod("WebChartViewer.compressMap", $self->{"this"}, $b, 4);
			if ($b && (length($b) > 2) && (substr($b, 0, 2)  == "\x1f\x8b"))
			{
				$ext = ".map.gz";
			}
		}

		$path =~ s/[\\\/]*$//;
		my $filename = perlchartdir::tmpFile2($path, $timeout, $ext);
		if ($filename ne "")
		{
			open(OUTFILE, ">$path/$filename");
			binmode(OUTFILE); 
			print OUTFILE $b;
			close(OUTFILE);
		}
		return $filename;
	};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $ret;
}

sub renderHTML
{
	my $ret = eval {
		my ($self, $extraAttrs) = @{perlchartdir::checkarg(\@_, 2, "")};
		my $url = defined $ENV{'SCRIPT_NAME'} ? $ENV{'SCRIPT_NAME'} : "";
		my $query = defined $ENV{'QUERY_STRING'} ? $ENV{'QUERY_STRING'} : "";
		return perlchartdir::callMethod("WebChartViewer.renderHTML", $self->{"this"}, $url, $query, $extraAttrs);	
		};
	if ((!$ret) && ($@)) { perlchartdir::printerr($@); }
	return $ret;
}
sub partialUpdateChart
{
	return "Content-type: text/html; charset=utf-8\n\n".perlchartdir::_m("WebChartViewer.partialUpdateChart", \@_, 2, "", 0);
}
	
sub isPartialUpdateRequest { return (defined $_[0]->{"request"}) && (defined $_[0]->{"request"}->param($j_p)); }
sub isFullUpdateRequest
{
	my $self = shift;
	if ($self->isPartialUpdateRequest()) { return 0; }
	if ($_[0]->{"request"}) {
		foreach $k ($_[0]->{"request"}->param) {
			if (substr($k, - length($j_s)) eq $j_s) { return 1; }
		}
	}
    return 0;
}
sub isStreamRequest { return (defined $_[0]->{"request"}) && (defined $_[0]->{"request"}->param($j_d)); }
sub isViewPortChangedEvent { return $_[0]->getAttrF(25, 0) != 0; }
sub getSenderClientId
{
	my $self = shift;
	if ($self->isPartialUpdateRequest()) { return $self->{"request"}->param($j_p); }
	elsif ($self->isStreamRequest()) { return $self->{"request"}->param($j_d); }
	else { return undef; }
}

sub getAttrS { return perlchartdir::_m("WebChartViewer.getAttrS", \@_, 2, ""); }
sub getAttrF { return perlchartdir::_m("WebChartViewer.getAttrF", \@_, 2, 0); }
sub putAttrF { perlchartdir::_m("WebChartViewer.putAttrF", \@_, 2); }
sub putAttrS { perlchartdir::_m("WebChartViewer.putAttrS", \@_, 2); }

sub getViewPortLeft { return $_[0]->getAttrF(4, 0); }
sub setViewPortLeft { $_[0]->putAttrF(4, $_[1]); }

sub getViewPortTop { return $_[0]->getAttrF(5, 0); }
sub setViewPortTop { $_[0]->putAttrF(5, $_[1]); }

sub getViewPortWidth { return $_[0]->getAttrF(6, 1); }
sub setViewPortWidth { $_[0]->putAttrF(6, $_[1]); }

sub getViewPortHeight { return $_[0]->getAttrF(7, 1); }
sub setViewPortHeight { $_[0]->putAttrF(7, $_[1]); }

sub getSelectionBorderWidth { return int($_[0]->getAttrF(8, 2)); }
sub setSelectionBorderWidth { $_[0]->putAttrF(8, $_[1]); }

sub getSelectionBorderColor { return $_[0]->getAttrS(9, "Black"); }
sub setSelectionBorderColor { $_[0]->putAttrS(9, $_[1]); }

sub getMouseUsage { return int($_[0]->getAttrF(10, $perlchartdir::MouseUsageDefault)); }
sub setMouseUsage { $_[0]->putAttrF(10, $_[1]); }

sub getScrollDirection { return int($_[0]->getAttrF(11, $perlchartdir::DirectionHorizontal)); }
sub setScrollDirection { $_[0]->putAttrF(11, $_[1]); }

sub getZoomDirection { return int($_[0]->getAttrF(12, $perlchartdir::DirectionHorizontal)); }
sub setZoomDirection { $_[0]->putAttrF(12, $_[1]); }

sub getZoomInRatio { return $_[0]->getAttrF(13, 2); }
sub setZoomInRatio { if ($_[1] > 0) { $_[0]->putAttrF(13, $_[1]); } }

sub getZoomOutRatio { return $_[0]->getAttrF(14, 0.5); }
sub setZoomOutRatio { if ($_[1] > 0) { $_[0]->putAttrF(14, $_[1]); } }

sub getZoomInWidthLimit { return $_[0]->getAttrF(15, 0.01); }
sub setZoomInWidthLimit { $_[0]->putAttrF(15, $_[1]); }

sub getZoomOutWidthLimit { return $_[0]->getAttrF(16, 1); }
sub setZoomOutWidthLimit { $_[0]->putAttrF(16, $_[1]); }

sub getZoomInHeightLimit { return $_[0]->getAttrF(17, 0.01); }
sub setZoomInHeightLimit { $_[0]->putAttrF(17, $_[1]); }

sub getZoomOutHeightLimit { return $_[0]->getAttrF(18, 1); }
sub setZoomOutHeightLimit { $_[0]->putAttrF(18, $_[1]); }
	
sub getMinimumDrag { return int($_[0]->getAttrF(19, 5)); }
sub setMinimumDrag { $_[0]->putAttrF(19, $_[1]); }

sub getZoomInCursor { return $_[0]->getAttrS(20, ""); }
sub setZoomInCursor { $_[0]->putAttrS(20, $_[1]); }

sub getZoomOutCursor { return $_[0]->getAttrS(21, ""); }
sub setZoomOutCursor { $_[0]->putAttrS(21, $_[1]); }

sub getScrollCursor { return $_[0]->getAttrS(22, ""); }
sub setScrollCursor { $_[0]->putAttrS(22, $_[1]); }

sub getNoZoomCursor { return $_[0]->getAttrS(26, ""); }
sub setNoZoomCursor { $_[0]->putAttrS(26, $_[1]); }

sub getCustomAttr { return $_[0]->getAttrS($_[1], ""); }
sub setCustomAttr { $_[0]->putAttrS($_[1], $_[2]); }

1;
