#!/usr/bin/perl

# Include current script directory in the module path (needed on Microsoft IIS).
# This allows this script to work by copying ChartDirector to the same directory
# as the script (as an alternative to installation in Perl module directory)
use File::Basename;
use lib dirname($0) =~ /(.*)/;

use perlchartdir;

#/////////////////////////////////////////////////////////////////////////////////////////////////
# Copyright 2008 Advanced Software Engineering Limited
#
# ChartDirector FinanceChart class library
#     - Requires ChartDirector Ver 5.0 or above
#
# You may use and modify the code in this file in your application, provided the code and
# its modifications are used only in conjunction with ChartDirector. Usage of this software
# is subjected to the terms and condition of the ChartDirector license.
#/////////////////////////////////////////////////////////////////////////////////////////////////

#/ <summary>
#/ Represents a Financial Chart
#/ </summary>
package FinanceChart;
@ISA = ("MultiChart");

sub init
{
    my $self = shift;
    $self->{'m_totalWidth'} = 0;
    $self->{'m_totalHeight'} = 0;
    $self->{'m_antiAlias'} = 1;
    $self->{'m_logScale'} = 0;
    $self->{'m_axisOnRight'} = 1;

    $self->{'m_leftMargin'} = 40;
    $self->{'m_rightMargin'} = 40;
    $self->{'m_topMargin'} = 30;
    $self->{'m_bottomMargin'} = 35;

    $self->{'m_plotAreaBgColor'} = 0xffffff;
    $self->{'m_plotAreaBorder'} = 0x888888;
    $self->{'m_plotAreaGap'} = 2;

    $self->{'m_majorHGridColor'} = 0xdddddd;
    $self->{'m_minorHGridColor'} = 0xdddddd;
    $self->{'m_majorVGridColor'} = 0xdddddd;
    $self->{'m_minorVGridColor'} = 0xdddddd;

    $self->{'m_legendFont'} = "normal";
    $self->{'m_legendFontSize'} = 8;
    $self->{'m_legendFontColor'} = $perlchartdir::TextColor;
    $self->{'m_legendBgColor'} = 0x80cccccc;

    $self->{'m_yAxisFont'} = "normal";
    $self->{'m_yAxisFontSize'} = 8;
    $self->{'m_yAxisFontColor'} = $perlchartdir::TextColor;
    $self->{'m_yAxisMargin'} = 14;

    $self->{'m_xAxisFont'} = "normal";
    $self->{'m_xAxisFontSize'} = 8;
    $self->{'m_xAxisFontColor'} = $perlchartdir::TextColor;
    $self->{'m_xAxisFontAngle'} = 0;

    $self->{'m_timeStamps'} = undef;
    $self->{'m_highData'} = undef;
    $self->{'m_lowData'} = undef;
    $self->{'m_openData'} = undef;
    $self->{'m_closeData'} = undef;
    $self->{'m_volData'} = undef;
    $self->{'m_volUnit'} = "";
    $self->{'m_extraPoints'} = 0;

    $self->{'m_yearFormat'} = "{value|yyyy}";
    $self->{'m_firstMonthFormat'} = "<*font=bold*>{value|mmm yy}";
    $self->{'m_otherMonthFormat'} = "{value|mmm}";
    $self->{'m_firstDayFormat'} = "<*font=bold*>{value|d mmm}";
    $self->{'m_otherDayFormat'} = "{value|d}";
    $self->{'m_firstHourFormat'} = "<*font=bold*>{value|d mmm\nh:nna}";
    $self->{'m_otherHourFormat'} = "{value|h:nna}";
    $self->{'m_timeLabelSpacing'} = 50;

    $self->{'m_generalFormat'} = "P3";

    $self->{'m_toolTipMonthFormat'} = "[{xLabel|mmm yyyy}]";
    $self->{'m_toolTipDayFormat'} = "[{xLabel|mmm d, yyyy}]";
    $self->{'m_toolTipHourFormat'} = "[{xLabel|mmm d, yyyy hh:nn:ss}]";

    $self->{'m_mainChart'} = undef;
    $self->{'m_currentChart'} = undef;
}

#/ <summary>
#/ Create a FinanceChart with a given width. The height will be automatically determined
#/ as the chart is built.
#/ </summary>
#/ <param name="width">Width of the chart in pixels</param>
sub new
{
    my ($class, $width) = @_;
    my $self = $class->SUPER::new($width, 1);
    bless($self, $class);
    $self->FinanceChart::init();
    $self->{'m_totalWidth'} = $width;
    return $self;
}

#/ <summary>
#/ Enable/Disable anti-alias. Enabling anti-alias makes the line smoother. Disabling
#/ anti-alias make the chart file size smaller, and so can be downloaded faster
#/ through the Internet. The default is to enable anti-alias.
#/ </summary>
#/ <param name="antiAlias">True to enable anti-alias. False to disable anti-alias.</param>
sub enableAntiAlias
{
    my ($self, $antiAlias) = @_;
    $self->{'m_antiAlias'} = $antiAlias;
}

#/ <summary>
#/ Set the margins around the plot area.
#/ </summary>
#/ <param name="m_leftMargin">The distance between the plot area and the chart left edge.</param>
#/ <param name="m_topMargin">The distance between the plot area and the chart top edge.</param>
#/ <param name="m_rightMargin">The distance between the plot area and the chart right edge.</param>
#/ <param name="m_bottomMargin">The distance between the plot area and the chart bottom edge.</param>
sub setMargins
{
    my ($self, $leftMargin, $topMargin, $rightMargin, $bottomMargin) = @_;
    $self->{'m_leftMargin'} = $leftMargin;
    $self->{'m_rightMargin'} = $rightMargin;
    $self->{'m_topMargin'} = $topMargin;
    $self->{'m_bottomMargin'} = $bottomMargin;
}

#/ <summary>
#/ Add a text title above the plot area. You may add multiple title above the plot area by
#/ calling this method multiple times.
#/ </summary>
#/ <param name="alignment">The alignment with respect to the region that is on top of the
#/ plot area.</param>
#/ <param name="text">The text to add.</param>
#/ <returns>The TextBox object representing the text box above the plot area.</returns>
sub addPlotAreaTitle
{
    my ($self, $alignment, $text) = @_;
    my $ret = $self->addText($self->{'m_leftMargin'}, 0, $text, "bold", 10,
        $perlchartdir::TextColor, $alignment);
    $ret->setSize($self->{'m_totalWidth'} - $self->{'m_leftMargin'} - $self->{'m_rightMargin'} + 1,
        $self->{'m_topMargin'} - 1);
    $ret->setMargin(0);
    return $ret;
}

#/ <summary>
#/ Set the plot area style. The default is to use pale yellow 0xfffff0 as the background,
#/ and light grey 0xdddddd as the grid lines.
#/ </summary>
#/ <param name="bgColor">The plot area background color.</param>
#/ <param name="majorHGridColor">Major horizontal grid color.</param>
#/ <param name="majorVGridColor">Major vertical grid color.</param>
#/ <param name="minorHGridColor">Minor horizontal grid color. In current version, minor
#/ horizontal grid is not used.</param>
#/ <param name="minorVGridColor">Minor vertical grid color.</param>
sub setPlotAreaStyle
{
    my ($self, $bgColor, $majorHGridColor, $majorVGridColor, $minorHGridColor, $minorVGridColor)
         = @_;
    $self->{'m_plotAreaBgColor'} = $bgColor;
    $self->{'m_majorHGridColor'} = $majorHGridColor;
    $self->{'m_majorVGridColor'} = $majorVGridColor;
    $self->{'m_minorHGridColor'} = $minorHGridColor;
    $self->{'m_minorVGridColor'} = $minorVGridColor;
}

#/ <summary>
#/ Set the plot area border style. The default is grey color (888888), with a gap
#/ of 2 pixels between charts.
#/ </summary>
#/ <param name="borderColor">The color of the border.</param>
#/ <param name="borderGap">The gap between two charts.</param>
sub setPlotAreaBorder
{
    my ($self, $borderColor, $borderGap) = @_;
    $self->{'m_plotAreaBorder'} = $borderColor;
    $self->{'m_plotAreaGap'} = $borderGap;
}

#/ <summary>
#/ Set legend style. The default is Arial 8 pt black color, with light grey background.
#/ </summary>
#/ <param name="font">The font of the legend text.</param>
#/ <param name="fontSize">The font size of the legend text in points.</param>
#/ <param name="fontColor">The color of the legend text.</param>
#/ <param name="bgColor">The background color of the legend box.</param>
sub setLegendStyle
{
    my ($self, $font, $fontSize, $fontColor, $bgColor) = @_;
    $self->{'m_legendFont'} = $font;
    $self->{'m_legendFontSize'} = $fontSize;
    $self->{'m_legendFontColor'} = $fontColor;
    $self->{'m_legendBgColor'} = $bgColor;
}

#/ <summary>
#/ Set x-axis label style. The default is Arial 8 pt black color no rotation.
#/ </summary>
#/ <param name="font">The font of the axis labels.</param>
#/ <param name="fontSize">The font size of the axis labels in points.</param>
#/ <param name="fontColor">The color of the axis labels.</param>
#/ <param name="fontAngle">The rotation of the axis labels.</param>
sub setXAxisStyle
{
    my ($self, $font, $fontSize, $fontColor, $fontAngle) = @_;
    $self->{'m_xAxisFont'} = $font;
    $self->{'m_xAxisFontSize'} = $fontSize;
    $self->{'m_xAxisFontColor'} = $fontColor;
    $self->{'m_xAxisFontAngle'} = $fontAngle;
}

#/ <summary>
#/ Set y-axis label style. The default is Arial 8 pt black color, with 13 pixels margin.
#/ </summary>
#/ <param name="font">The font of the axis labels.</param>
#/ <param name="fontSize">The font size of the axis labels in points.</param>
#/ <param name="fontColor">The color of the axis labels.</param>
#/ <param name="axisMargin">The margin at the top of the y-axis in pixels (to leave
#/ space for the legend box).</param>
sub setYAxisStyle
{
    my ($self, $font, $fontSize, $fontColor, $axisMargin) = @_;
    $self->{'m_yAxisFont'} = $font;
    $self->{'m_yAxisFontSize'} = $fontSize;
    $self->{'m_yAxisFontColor'} = $fontColor;
    $self->{'m_yAxisMargin'} = $axisMargin;
}

#/ <summary>
#/ Set whether the main y-axis is on right of left side of the plot area. The default is
#/ on right.
#/ </summary>
#/ <param name="b">True if the y-axis is on right. False if the y-axis is on left.</param>
sub setAxisOnRight
{
    my ($self, $b) = @_;
    $self->{'m_axisOnRight'} = $b;
}

#/ <summary>
#/ Determines if log scale should be used for the main chart. The default is linear scale.
#/ </summary>
#/ <param name="b">True for using log scale. False for using linear scale.</param>
sub setLogScale
{
    my ($self, $b) = @_;
    $self->{'m_logScale'} = $b;
    if (defined($self->{'m_mainChart'})) {
        if ($self->{'m_logScale'}) {
            $self->{'m_mainChart'}->yAxis()->setLogScale();
        } else {
            $self->{'m_mainChart'}->yAxis()->setLinearScale();
        }
    }
}

#/ <summary>
#/ Set the date/time formats to use for the x-axis labels under various cases.
#/ </summary>
#/ <param name="yearFormat">The format for displaying labels on an axis with yearly ticks. The
#/ default is "yyyy".</param>
#/ <param name="firstMonthFormat">The format for displaying labels on an axis with monthly ticks.
#/ This parameter applies to the first available month of a year (usually January) only, so it can
#/ be formatted differently from the other labels.</param>
#/ <param name="otherMonthFormat">The format for displaying labels on an axis with monthly ticks.
#/ This parameter applies to months other than the first available month of a year.</param>
#/ <param name="firstDayFormat">The format for displaying labels on an axis with daily ticks.
#/ This parameter applies to the first available day of a month only, so it can be formatted
#/ differently from the other labels.</param>
#/ <param name="otherDayFormat">The format for displaying labels on an axis with daily ticks.
#/ This parameter applies to days other than the first available day of a month.</param>
#/ <param name="firstHourFormat">The format for displaying labels on an axis with hourly
#/ resolution. This parameter applies to the first tick of a day only, so it can be formatted
#/ differently from the other labels.</param>
#/ <param name="otherHourFormat">The format for displaying labels on an axis with hourly.
#/ resolution. This parameter applies to ticks at hourly boundaries, except the first tick
#/ of a day.</param>
sub setDateLabelFormat
{
    my ($self, $yearFormat, $firstMonthFormat, $otherMonthFormat, $firstDayFormat, $otherDayFormat,
        $firstHourFormat, $otherHourFormat) = @_;
    if (defined($yearFormat)) {
        $self->{'m_yearFormat'} = $yearFormat;
    }
    if (defined($firstMonthFormat)) {
        $self->{'m_firstMonthFormat'} = $firstMonthFormat;
    }
    if (defined($otherMonthFormat)) {
        $self->{'m_otherMonthFormat'} = $otherMonthFormat;
    }
    if (defined($firstDayFormat)) {
        $self->{'m_firstDayFormat'} = $firstDayFormat;
    }
    if (defined($otherDayFormat)) {
        $self->{'m_otherDayFormat'} = $otherDayFormat;
    }
    if (defined($firstHourFormat)) {
        $self->{'m_firstHourFormat'} = $firstHourFormat;
    }
    if (defined($otherHourFormat)) {
        $self->{'m_otherHourFormat'} = $otherHourFormat;
    }
}

#/ <summary>
#/ Set the minimum label spacing between two labels on the time axis
#/ </summary>
#/ <param name="labelSpacing">The minimum label spacing in pixels.</param>
sub setDateLabelSpacing
{
    my ($self, $labelSpacing) = @_;
    if ($labelSpacing > 0) {
        $self->{'m_timeLabelSpacing'} = $labelSpacing;
    } else {
         $self->{'m_timeLabelSpacing'} = 0;
    }
}

#/ <summary>
#/ Set the tool tip formats for display date/time
#/ </summary>
#/ <param name="monthFormat">The tool tip format to use if the data point spacing is one
#/ or more months (more than 30 days).</param>
#/ <param name="dayFormat">The tool tip format to use if the data point spacing is 1 day
#/ to less than 30 days.</param>
#/ <param name="hourFormat">The tool tip format to use if the data point spacing is less
#/ than 1 day.</param>
sub setToolTipDateFormat
{
    my ($self, $monthFormat, $dayFormat, $hourFormat) = @_;
    if (defined($monthFormat)) {
        $self->{'m_toolTipMonthFormat'} = $monthFormat;
    }
    if (defined($dayFormat)) {
        $self->{'m_toolTipDayFormat'} = $dayFormat;
    }
    if (defined($hourFormat)) {
        $self->{'m_toolTipHourFormat'} = $hourFormat;
    }
}

#/ <summary>
#/ Get the tool tip format for display date/time
#/ </summary>
#/ <returns>The tool tip format string.</returns>
sub getToolTipDateFormat
{
    my ($self) = @_;
    if (!defined($self->{'m_timeStamps'})) {
        return $self->{'m_toolTipHourFormat'};
    }
    if (scalar(@{$self->{'m_timeStamps'}}) <= $self->{'m_extraPoints'}) {
        return $self->{'m_toolTipHourFormat'};
    }
    my $resolution = ($self->{'m_timeStamps'}->[scalar(@{$self->{'m_timeStamps'}}) - 1] -
        $self->{'m_timeStamps'}->[0]) / scalar(@{$self->{'m_timeStamps'}});
    if ($resolution >= 30 * 86400) {
        return $self->{'m_toolTipMonthFormat'};
    } elsif ($resolution >= 86400) {
        return $self->{'m_toolTipDayFormat'};
    } else {
        return $self->{'m_toolTipHourFormat'};
    }
}

#/ <summary>
#/ Set the number format for use in displaying values in legend keys and tool tips.
#/ </summary>
#/ <param name="formatString">The default number format.</param>
sub setNumberLabelFormat
{
    my ($self, $formatString) = @_;
    if (defined($formatString)) {
        $self->{'m_generalFormat'} = $formatString;
    }
}

#/ <summary>
#/ A utility function to compute triangular moving averages
#/ </summary>
#/ <param name="data">An array of numbers as input.</param>
#/ <param name="period">The moving average period.</param>
#/ <returns>An array representing the triangular moving average of the input array.</returns>
sub computeTriMovingAvg
{
    my ($self, $data, $period) = @_;
    my $p = $period / 2 + 1;
    return new ArrayMath($data)->movAvg($p)->movAvg($p)->result();
}

#/ <summary>
#/ A utility function to compute weighted moving averages
#/ </summary>
#/ <param name="data">An array of numbers as input.</param>
#/ <param name="period">The moving average period.</param>
#/ <returns>An array representing the weighted moving average of the input array.</returns>
sub computeWeightedMovingAvg
{
    my ($self, $data, $period) = @_;
    my $acc = new ArrayMath($data);
    for(my $i = 2; $i < $period + 1; ++$i) {
        $acc->add(new ArrayMath($data)->movAvg($i)->mul($i)->result());
    }
    return $acc->div((1 + $period) * $period / 2)->result();
}

#/ <summary>
#/ A utility function to obtain the first visible closing price.
#/ </summary>
#/ <returns>The first closing price.
#/ are cd.NoValue.</returns>
sub firstCloseValue
{
    my ($self) = @_;
    for(my $i = $self->{'m_extraPoints'}; $i < scalar(@{$self->{'m_closeData'}}); ++$i) {
        if (($self->{'m_closeData'}->[$i] != $perlchartdir::NoValue) && ($self->{'m_closeData'}->[$i
            ] != 0)) {
            return $self->{'m_closeData'}->[$i];
        }
    }
    return $perlchartdir::NoValue;
}

#/ <summary>
#/ A utility function to obtain the last valid position (that is, position not
#/ containing cd.NoValue) of a data series.
#/ </summary>
#/ <param name="data">An array of numbers as input.</param>
#/ <returns>The last valid position in the input array, or -1 if all positions
#/ are cd.NoValue.</returns>
sub lastIndex
{
    my ($self, $data) = @_;
    my $i = scalar(@$data) - 1;
    while ($i >= 0) {
        if ($data->[$i] != $perlchartdir::NoValue) {
            last;
        }
        $i = $i - 1;
    }
    return $i;
}

#/ <summary>
#/ Set the data used in the chart. If some of the data are not available, some artifical
#/ values should be used. For example, if the high and low values are not available, you
#/ may use closeData as highData and lowData.
#/ </summary>
#/ <param name="timeStamps">An array of dates/times for the time intervals.</param>
#/ <param name="highData">The high values in the time intervals.</param>
#/ <param name="lowData">The low values in the time intervals.</param>
#/ <param name="openData">The open values in the time intervals.</param>
#/ <param name="closeData">The close values in the time intervals.</param>
#/ <param name="volData">The volume values in the time intervals.</param>
#/ <param name="extraPoints">The number of leading time intervals that are not
#/ displayed in the chart. These intervals are typically used for computing
#/ indicators that require extra leading data, such as moving averages.</param>
sub setData
{
    my ($self, $timeStamps, $highData, $lowData, $openData, $closeData, $volData, $extraPoints)
         = @_;
    $self->{'m_timeStamps'} = $timeStamps;
    $self->{'m_highData'} = $highData;
    $self->{'m_lowData'} = $lowData;
    $self->{'m_openData'} = $openData;
    $self->{'m_closeData'} = $closeData;
    if ($extraPoints > 0) {
        $self->{'m_extraPoints'} = $extraPoints;
    } else {
        $self->{'m_extraPoints'} = 0;
    }

    #///////////////////////////////////////////////////////////////////////
    # Auto-detect volume units
    #///////////////////////////////////////////////////////////////////////
    my $maxVol = new ArrayMath($volData)->max();
    my $units = ["", "K", "M", "B"];
    my $unitIndex = scalar(@$units) - 1;
    while (($unitIndex > 0) && ($maxVol < 1000**$unitIndex)) {
        $unitIndex = $unitIndex - 1;
    }

    $self->{'m_volData'} = new ArrayMath($volData)->div(1000**$unitIndex)->result();
    $self->{'m_volUnit'} = $units->[$unitIndex];
}

#////////////////////////////////////////////////////////////////////////////
# Format x-axis labels
#////////////////////////////////////////////////////////////////////////////
sub setXLabels
{
    my ($self, $a) = @_;
    $a->setLabels2($self->{'m_timeStamps'});
    if ($self->{'m_extraPoints'} < scalar(@{$self->{'m_timeStamps'}})) {
        my $tickStep = int((scalar(@{$self->{'m_timeStamps'}}) - $self->{'m_extraPoints'}) *
            $self->{'m_timeLabelSpacing'} / ($self->{'m_totalWidth'} - $self->{'m_leftMargin'} -
            $self->{'m_rightMargin'})) + 1;
        my $timeRangeInSeconds = $self->{'m_timeStamps'}->[scalar(@{$self->{'m_timeStamps'}}) - 1] -
            $self->{'m_timeStamps'}->[$self->{'m_extraPoints'}];
        my $secondsBetweenTicks = $timeRangeInSeconds / ($self->{'m_totalWidth'} -
            $self->{'m_leftMargin'} - $self->{'m_rightMargin'}) * $self->{'m_timeLabelSpacing'};

        if ($secondsBetweenTicks * (scalar(@{$self->{'m_timeStamps'}}) - $self->{'m_extraPoints'})
             <= $timeRangeInSeconds) {
            $tickStep = 1;
            if (scalar(@{$self->{'m_timeStamps'}}) > 1) {
                $secondsBetweenTicks = $self->{'m_timeStamps'}->[scalar(@{$self->{'m_timeStamps'}})
                     - 1] - $self->{'m_timeStamps'}->[scalar(@{$self->{'m_timeStamps'}}) - 2];
            } else {
                $secondsBetweenTicks = 86400;
            }
        }

        if (($secondsBetweenTicks > 360 * 86400) || (($secondsBetweenTicks > 90 * 86400) && (
            $timeRangeInSeconds >= 720 * 86400))) {
            #yearly ticks
            $a->setMultiFormat2(perlchartdir::StartOfYearFilter(), $self->{'m_yearFormat'},
                $tickStep);
        } elsif (($secondsBetweenTicks >= 30 * 86400) || (($secondsBetweenTicks > 7 * 86400) && (
            $timeRangeInSeconds >= 60 * 86400))) {
            #monthly ticks
            my $monthBetweenTicks = int($secondsBetweenTicks / 31 / 86400) + 1;
            $a->setMultiFormat(perlchartdir::StartOfYearFilter(), $self->{'m_firstMonthFormat'},
                perlchartdir::StartOfMonthFilter($monthBetweenTicks), $self->{'m_otherMonthFormat'})
                ;
            $a->setMultiFormat2(perlchartdir::StartOfMonthFilter(), "-", 1, 0);
        } elsif (($secondsBetweenTicks >= 86400) || (($secondsBetweenTicks > 6 * 3600) && (
            $timeRangeInSeconds >= 86400))) {
            #daily ticks
            $a->setMultiFormat(perlchartdir::StartOfMonthFilter(), $self->{'m_firstDayFormat'},
                perlchartdir::StartOfDayFilter(1, 0.5), $self->{'m_otherDayFormat'}, $tickStep);
        } else {
            #hourly ticks
            $a->setMultiFormat(perlchartdir::StartOfDayFilter(1, 0.5), $self->{'m_firstHourFormat'},
                perlchartdir::StartOfHourFilter(1, 0.5), $self->{'m_otherHourFormat'}, $tickStep);
        }
    }
}

#////////////////////////////////////////////////////////////////////////////
# Create tool tip format string for showing OHLC data
#////////////////////////////////////////////////////////////////////////////
sub getHLOCToolTipFormat
{
    my ($self) = @_;
    return sprintf("title='%s Op:{open|%s}, Hi:{high|%s}, Lo:{low|%s}, Cl:{close|%s}'",
        $self->getToolTipDateFormat(), $self->{'m_generalFormat'}, $self->{'m_generalFormat'},
        $self->{'m_generalFormat'}, $self->{'m_generalFormat'});
}

#/ <summary>
#/ Add the main chart - the chart that shows the HLOC data.
#/ </summary>
#/ <param name="height">The height of the main chart in pixels.</param>
#/ <returns>An XYChart object representing the main chart created.</returns>
sub addMainChart
{
    my ($self, $height) = @_;
    $self->{'m_mainChart'} = $self->addIndicator($height);
    $self->setMainChart($self->{'m_mainChart'});
    $self->{'m_mainChart'}->yAxis()->setMargin(2 * $self->{'m_yAxisMargin'});
    if ($self->{'m_logScale'}) {
        $self->{'m_mainChart'}->yAxis()->setLogScale();
    } else {
        $self->{'m_mainChart'}->yAxis()->setLinearScale();
    }
    return $self->{'m_mainChart'};
}

#/ <summary>
#/ Add a candlestick layer to the main chart.
#/ </summary>
#/ <param name="upColor">The candle color for an up day.</param>
#/ <param name="downColor">The candle color for a down day.</param>
#/ <returns>The CandleStickLayer created.</returns>
sub addCandleStick
{
    my ($self, $upColor, $downColor) = @_;
    $self->addOHLCLabel($upColor, $downColor, 1);
    my $ret = $self->{'m_mainChart'}->addCandleStickLayer($self->{'m_highData'},
        $self->{'m_lowData'}, $self->{'m_openData'}, $self->{'m_closeData'}, $upColor, $downColor);
    $ret->setHTMLImageMap("", "", $self->getHLOCToolTipFormat());
    if (scalar(@{$self->{'m_highData'}}) - $self->{'m_extraPoints'} > 60) {
        $ret->setDataGap(0);
    }

    if (scalar(@{$self->{'m_highData'}}) > $self->{'m_extraPoints'}) {
        my $expectedWidth = ($self->{'m_totalWidth'} - $self->{'m_leftMargin'} -
            $self->{'m_rightMargin'}) / (scalar(@{$self->{'m_highData'}}) - $self->{'m_extraPoints'}
            );
        if ($expectedWidth <= 5) {
            $ret->setDataWidth($expectedWidth + 1 - $expectedWidth % 2);
        }
    }

    return $ret;
}

#/ <summary>
#/ Add a HLOC layer to the main chart.
#/ </summary>
#/ <param name="upColor">The color of the HLOC symbol for an up day.</param>
#/ <param name="downColor">The color of the HLOC symbol for a down day.</param>
#/ <returns>The HLOCLayer created.</returns>
sub addHLOC
{
    my ($self, $upColor, $downColor) = @_;
    $self->addOHLCLabel($upColor, $downColor, 0);
    my $ret = $self->{'m_mainChart'}->addHLOCLayer($self->{'m_highData'}, $self->{'m_lowData'},
        $self->{'m_openData'}, $self->{'m_closeData'});
    $ret->setColorMethod($perlchartdir::HLOCUpDown, $upColor, $downColor);
    $ret->setHTMLImageMap("", "", $self->getHLOCToolTipFormat());
    $ret->setDataGap(0);
    return $ret;
}

sub addOHLCLabel
{
    my ($self, $upColor, $downColor, $candleStickMode) = @_;
    my $i = $self->lastIndex($self->{'m_closeData'});
    if ($i >= 0) {
        my $openValue = $perlchartdir::NoValue;
        my $closeValue = $perlchartdir::NoValue;
        my $highValue = $perlchartdir::NoValue;
        my $lowValue = $perlchartdir::NoValue;

        if ($i < scalar(@{$self->{'m_openData'}})) {
            $openValue = $self->{'m_openData'}->[$i];
        }
        if ($i < scalar(@{$self->{'m_closeData'}})) {
            $closeValue = $self->{'m_closeData'}->[$i];
        }
        if ($i < scalar(@{$self->{'m_highData'}})) {
            $highValue = $self->{'m_highData'}->[$i];
        }
        if ($i < scalar(@{$self->{'m_lowData'}})) {
            $lowValue = $self->{'m_lowData'}->[$i];
        }

        my $openLabel = "";
        my $closeLabel = "";
        my $highLabel = "";
        my $lowLabel = "";
        my $delim = "";
        if ($openValue != $perlchartdir::NoValue) {
            $openLabel = sprintf("Op:%s", $self->formatValue($openValue, $self->{'m_generalFormat'})
                );
            $delim = ", ";
        }
        if ($highValue != $perlchartdir::NoValue) {
            $highLabel = sprintf("%sHi:%s", $delim, $self->formatValue($highValue,
                $self->{'m_generalFormat'}));
            $delim = ", ";
        }
        if ($lowValue != $perlchartdir::NoValue) {
            $lowLabel = sprintf("%sLo:%s", $delim, $self->formatValue($lowValue,
                $self->{'m_generalFormat'}));
            $delim = ", ";
        }
        if ($closeValue != $perlchartdir::NoValue) {
            $closeLabel = sprintf("%sCl:%s", $delim, $self->formatValue($closeValue,
                $self->{'m_generalFormat'}));
            $delim = ", ";
        }
        my $label = "$openLabel$highLabel$lowLabel$closeLabel";

        my $useUpColor = ($closeValue >= $openValue);
        if ($candleStickMode != 1) {
            my $closeChanges = new ArrayMath($self->{'m_closeData'})->delta()->result();
            my $lastChangeIndex = $self->lastIndex($closeChanges);
            $useUpColor = ($lastChangeIndex < 0);
            if ($useUpColor != 1) {
                $useUpColor = ($closeChanges->[$lastChangeIndex] >= 0);
            }
        }

        my $udcolor = $downColor;
        if ($useUpColor) {
            $udcolor = $upColor;
        }
        $self->{'m_mainChart'}->getLegend()->addKey($label, $udcolor);
    }
}

#/ <summary>
#/ Add a closing price line on the main chart.
#/ </summary>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addCloseLine
{
    my ($self, $color) = @_;
    return $self->addLineIndicator2($self->{'m_mainChart'}, $self->{'m_closeData'}, $color,
        "Closing Price");
}

#/ <summary>
#/ Add a weight close line on the main chart.
#/ </summary>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addWeightedClose
{
    my ($self, $color) = @_;
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath($self->{'m_highData'}
        )->add($self->{'m_lowData'})->add($self->{'m_closeData'})->add($self->{'m_closeData'})->div(
        4)->result(), $color, "Weighted Close");
}

#/ <summary>
#/ Add a typical price line on the main chart.
#/ </summary>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addTypicalPrice
{
    my ($self, $color) = @_;
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath($self->{'m_highData'}
        )->add($self->{'m_lowData'})->add($self->{'m_closeData'})->div(3)->result(), $color,
        "Typical Price");
}

#/ <summary>
#/ Add a median price line on the main chart.
#/ </summary>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addMedianPrice
{
    my ($self, $color) = @_;
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath($self->{'m_highData'}
        )->add($self->{'m_lowData'})->div(2)->result(), $color, "Median Price");
}

#/ <summary>
#/ Add a simple moving average line on the main chart.
#/ </summary>
#/ <param name="period">The moving average period</param>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addSimpleMovingAvg
{
    my ($self, $period, $color) = @_;
    my $label = "SMA ($period)";
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath($self->{'m_closeData'}
        )->movAvg($period)->result(), $color, $label);
}

#/ <summary>
#/ Add an exponential moving average line on the main chart.
#/ </summary>
#/ <param name="period">The moving average period</param>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addExpMovingAvg
{
    my ($self, $period, $color) = @_;
    my $label = "EMA ($period)";
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath($self->{'m_closeData'}
        )->expAvg(2.0 / ($period + 1))->result(), $color, $label);
}

#/ <summary>
#/ Add a triangular moving average line on the main chart.
#/ </summary>
#/ <param name="period">The moving average period</param>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addTriMovingAvg
{
    my ($self, $period, $color) = @_;
    my $label = "TMA ($period)";
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath(
        $self->computeTriMovingAvg($self->{'m_closeData'}, $period))->result(), $color, $label);
}

#/ <summary>
#/ Add a weighted moving average line on the main chart.
#/ </summary>
#/ <param name="period">The moving average period</param>
#/ <param name="color">The color of the line.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addWeightedMovingAvg
{
    my ($self, $period, $color) = @_;
    my $label = "WMA ($period)";
    return $self->addLineIndicator2($self->{'m_mainChart'}, new ArrayMath(
        $self->computeWeightedMovingAvg($self->{'m_closeData'}, $period))->result(), $color, $label)
        ;
}

#/ <summary>
#/ Add a parabolic SAR indicator to the main chart.
#/ </summary>
#/ <param name="accInitial">Initial acceleration factor</param>
#/ <param name="accIncrement">Acceleration factor increment</param>
#/ <param name="accMaximum">Maximum acceleration factor</param>
#/ <param name="symbolType">The symbol used to plot the parabolic SAR</param>
#/ <param name="symbolSize">The symbol size in pixels</param>
#/ <param name="fillColor">The fill color of the symbol</param>
#/ <param name="edgeColor">The edge color of the symbol</param>
#/ <returns>The LineLayer object representing the layer created.</returns>
sub addParabolicSAR
{
    my ($self, $accInitial, $accIncrement, $accMaximum, $symbolType, $symbolSize, $fillColor,
        $edgeColor) = @_;
    my $isLong = 1;
    my $acc = $accInitial;
    my $extremePoint = 0;
    my $psar = [(0) x scalar(@{$self->{'m_lowData'}})];

    my $i_1 = -1;
    my $i_2 = -1;

    for(my $i = 0; $i < scalar(@{$self->{'m_lowData'}}); ++$i) {
        $psar->[$i] = $perlchartdir::NoValue;
        if (($self->{'m_lowData'}->[$i] != $perlchartdir::NoValue) && ($self->{'m_highData'}->[$i]
             != $perlchartdir::NoValue)) {
            if (($i_1 >= 0) && ($i_2 < 0)) {
                if ($self->{'m_lowData'}->[$i_1] <= $self->{'m_lowData'}->[$i]) {
                    $psar->[$i] = $self->{'m_lowData'}->[$i_1];
                    $isLong = 1;
                    if ($self->{'m_highData'}->[$i_1] > $self->{'m_highData'}->[$i]) {
                        $extremePoint = $self->{'m_highData'}->[$i_1];
                    } else {
                        $extremePoint = $self->{'m_highData'}->[$i];
                    }
                } else {
                    $extremePoint = $self->{'m_lowData'}->[$i];
                    $isLong = 0;
                    if ($self->{'m_highData'}->[$i_1] > $self->{'m_highData'}->[$i]) {
                        $psar->[$i] = $self->{'m_highData'}->[$i_1];
                    } else {
                        $psar->[$i] = $self->{'m_highData'}->[$i];
                    }
                }
            } elsif (($i_1 >= 0) && ($i_2 >= 0)) {
                if ($acc > $accMaximum) {
                    $acc = $accMaximum;
                }

                $psar->[$i] = $psar->[$i_1] + $acc * ($extremePoint - $psar->[$i_1]);

                if ($isLong) {
                    if ($self->{'m_lowData'}->[$i] < $psar->[$i]) {
                        $isLong = 0;
                        $psar->[$i] = $extremePoint;
                        $extremePoint = $self->{'m_lowData'}->[$i];
                        $acc = $accInitial;
                    } else {
                        if ($self->{'m_highData'}->[$i] > $extremePoint) {
                            $extremePoint = $self->{'m_highData'}->[$i];
                            $acc = $acc + $accIncrement;
                        }

                        if ($self->{'m_lowData'}->[$i_1] < $psar->[$i]) {
                            $psar->[$i] = $self->{'m_lowData'}->[$i_1];
                        }
                        if ($self->{'m_lowData'}->[$i_2] < $psar->[$i]) {
                            $psar->[$i] = $self->{'m_lowData'}->[$i_2];
                        }
                    }
                } else {
                    if ($self->{'m_highData'}->[$i] > $psar->[$i]) {
                        $isLong = 1;
                        $psar->[$i] = $extremePoint;
                        $extremePoint = $self->{'m_highData'}->[$i];
                        $acc = $accInitial;
                    } else {
                        if ($self->{'m_lowData'}->[$i] < $extremePoint) {
                            $extremePoint = $self->{'m_lowData'}->[$i];
                            $acc = $acc + $accIncrement;
                        }

                        if ($self->{'m_highData'}->[$i_1] > $psar->[$i]) {
                            $psar->[$i] = $self->{'m_highData'}->[$i_1];
                        }
                        if ($self->{'m_highData'}->[$i_2] > $psar->[$i]) {
                            $psar->[$i] = $self->{'m_highData'}->[$i_2];
                        }
                    }
                }
            }

            $i_2 = $i_1;
            $i_1 = $i;
        }
    }

    my $ret = $self->addLineIndicator2($self->{'m_mainChart'}, $psar, $fillColor, "Parabolic SAR");
    $ret->setLineWidth(0);
    $ret->addDataSet($psar)->setDataSymbol($symbolType, $symbolSize, $fillColor, $edgeColor);
    return $ret;
}

#/ <summary>
#/ Add a comparison line to the main price chart.
#/ </summary>
#/ <param name="data">The data series to compare to</param>
#/ <param name="color">The color of the comparison line</param>
#/ <param name="name">The name of the comparison line</param>
#/ <returns>The LineLayer object representing the line layer created.</returns>
sub addComparison
{
    my ($self, $data, $color, $name) = @_;
    my $firstIndex = $self->{'m_extraPoints'};
    while (($firstIndex < scalar(@$data)) && ($firstIndex < scalar(@{$self->{'m_closeData'}}))) {
        if (($data->[$firstIndex] != $perlchartdir::NoValue) && ($self->{'m_closeData'}->[
            $firstIndex] != $perlchartdir::NoValue) && ($data->[$firstIndex] != 0) && (
            $self->{'m_closeData'}->[$firstIndex] != 0)) {
            last;
        }
        $firstIndex = $firstIndex + 1;
    }
    if (($firstIndex >= scalar(@$data)) || ($firstIndex >= scalar(@{$self->{'m_closeData'}}))) {
        return undef;
    }

    my $scaleFactor = $self->{'m_closeData'}->[$firstIndex] / $data->[$firstIndex];
    my $layer = $self->{'m_mainChart'}->addLineLayer(new ArrayMath($data)->mul($scaleFactor
        )->result(), $perlchartdir::Transparent);
    $layer->setHTMLImageMap("{disable}");

    my $a = $self->{'m_mainChart'}->addAxis($perlchartdir::Right, 0);
    $a->setColors($perlchartdir::Transparent, $perlchartdir::Transparent);
    $a->syncAxis($self->{'m_mainChart'}->yAxis(), 1 / $scaleFactor, 0);

    my $ret = $self->addLineIndicator2($self->{'m_mainChart'}, $data, $color, $name);
    $ret->setUseYAxis($a);
    return $ret;
}

#/ <summary>
#/ Display percentage axis scale
#/ </summary>
#/ <returns>The Axis object representing the percentage axis.</returns>
sub setPercentageAxis
{
    my ($self) = @_;
    my $firstClose = $self->firstCloseValue();
    if ($firstClose == $perlchartdir::NoValue) {
        return undef;
    }

    my $axisAlign = $perlchartdir::Left;
    if ($self->{'m_axisOnRight'}) {
        $axisAlign = $perlchartdir::Right;
    }

    my $ret = $self->{'m_mainChart'}->addAxis($axisAlign, 0);
    $self->configureYAxis($ret, 300);
    $ret->syncAxis($self->{'m_mainChart'}->yAxis(), 100 / $firstClose);
    $ret->setRounding(0, 0);
    $ret->setLabelFormat("{={value}-100|@}%");
    $self->{'m_mainChart'}->yAxis()->setColors($perlchartdir::Transparent,
        $perlchartdir::Transparent);
    $self->{'m_mainChart'}->getPlotArea()->setGridAxis(undef, $ret);
    return $ret;
}

#/ <summary>
#/ Add a generic band to the main finance chart. This method is used internally by other methods to add
#/ various bands (eg. Bollinger band, Donchian channels, etc).
#/ </summary>
#/ <param name="upperLine">The data series for the upper band line.</param>
#/ <param name="lowerLine">The data series for the lower band line.</param>
#/ <param name="lineColor">The color of the upper and lower band line.</param>
#/ <param name="fillColor">The color to fill the region between the upper and lower band lines.</param>
#/ <param name="name">The name of the band.</param>
#/ <returns>An InterLineLayer object representing the filled region.</returns>
sub addBand
{
    my ($self, $upperLine, $lowerLine, $lineColor, $fillColor, $name) = @_;
    my $i = scalar(@$upperLine) - 1;
    if ($i >= scalar(@$lowerLine)) {
        $i = scalar(@$lowerLine) - 1;
    }

    while ($i >= 0) {
        if (($upperLine->[$i] != $perlchartdir::NoValue) && ($lowerLine->[$i] !=
            $perlchartdir::NoValue)) {
            $name = sprintf("%s: %s - %s", $name, $self->formatValue($lowerLine->[$i],
                $self->{'m_generalFormat'}), $self->formatValue($upperLine->[$i],
                $self->{'m_generalFormat'}));
            last;
        }
        $i = $i - 1;
    }

    my $uLayer = $self->{'m_mainChart'}->addLineLayer($upperLine, $lineColor, $name);
    my $lLayer = $self->{'m_mainChart'}->addLineLayer($lowerLine, $lineColor);
    return $self->{'m_mainChart'}->addInterLineLayer($uLayer->getLine(), $lLayer->getLine(),
        $fillColor);
}

#/ <summary>
#/ Add a Bollinger band on the main chart.
#/ </summary>
#/ <param name="period">The period to compute the band.</param>
#/ <param name="bandWidth">The half-width of the band in terms multiples of standard deviation. Typically 2 is used.</param>
#/ <param name="lineColor">The color of the lines defining the upper and lower limits.</param>
#/ <param name="fillColor">The color to fill the regional within the band.</param>
#/ <returns>The InterLineLayer object representing the band created.</returns>
sub addBollingerBand
{
    my ($self, $period, $bandWidth, $lineColor, $fillColor) = @_;
    #Bollinger Band is moving avg +/- (width * moving std deviation)
    my $stdDev = new ArrayMath($self->{'m_closeData'})->movStdDev($period)->mul($bandWidth)->result(
        );
    my $movAvg = new ArrayMath($self->{'m_closeData'})->movAvg($period)->result();
    my $label = "Bollinger ($period, $bandWidth)";
    return $self->addBand(new ArrayMath($movAvg)->add($stdDev)->result(), new ArrayMath($movAvg
        )->sub($stdDev)->selectGTZ(undef, 0)->result(), $lineColor, $fillColor, $label);
}

#/ <summary>
#/ Add a Donchian channel on the main chart.
#/ </summary>
#/ <param name="period">The period to compute the band.</param>
#/ <param name="lineColor">The color of the lines defining the upper and lower limits.</param>
#/ <param name="fillColor">The color to fill the regional within the band.</param>
#/ <returns>The InterLineLayer object representing the band created.</returns>
sub addDonchianChannel
{
    my ($self, $period, $lineColor, $fillColor) = @_;
    #Donchian Channel is the zone between the moving max and moving min
    my $label = "Donchian ($period)";
    return $self->addBand(new ArrayMath($self->{'m_highData'})->movMax($period)->result(),
        new ArrayMath($self->{'m_lowData'})->movMin($period)->result(), $lineColor, $fillColor,
        $label);
}

#/ <summary>
#/ Add a price envelop on the main chart. The price envelop is a defined as a ratio around a
#/ moving average. For example, a ratio of 0.2 means 20% above and below the moving average.
#/ </summary>
#/ <param name="period">The period for the moving average.</param>
#/ <param name="range">The ratio above and below the moving average.</param>
#/ <param name="lineColor">The color of the lines defining the upper and lower limits.</param>
#/ <param name="fillColor">The color to fill the regional within the band.</param>
#/ <returns>The InterLineLayer object representing the band created.</returns>
sub addEnvelop
{
    my ($self, $period, $range, $lineColor, $fillColor) = @_;
    #Envelop is moving avg +/- percentage
    my $movAvg = new ArrayMath($self->{'m_closeData'})->movAvg($period)->result();
    my $label = sprintf("Envelop (SMA %s +/- %s%)", $period, int($range * 100));
    return $self->addBand(new ArrayMath($movAvg)->mul(1 + $range)->result(), new ArrayMath($movAvg
        )->mul(1 - $range)->result(), $lineColor, $fillColor, $label);
}

#/ <summary>
#/ Add a volume bar chart layer on the main chart.
#/ </summary>
#/ <param name="height">The height of the bar chart layer in pixels.</param>
#/ <param name="upColor">The color to used on an 'up' day. An 'up' day is a day where
#/ the closing price is higher than that of the previous day.</param>
#/ <param name="downColor">The color to used on a 'down' day. A 'down' day is a day
#/ where the closing price is lower than that of the previous day.</param>
#/ <param name="flatColor">The color to used on a 'flat' day. A 'flat' day is a day
#/ where the closing price is the same as that of the previous day.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addVolBars
{
    my ($self, $height, $upColor, $downColor, $flatColor) = @_;
    return $self->addVolBars2($self->{'m_mainChart'}, $height, $upColor, $downColor, $flatColor);
}

sub addVolBars2
{
    my ($self, $c, $height, $upColor, $downColor, $flatColor) = @_;
    my $barLayer = $c->addBarLayer2($perlchartdir::Overlay);
    $barLayer->setBorderColor($perlchartdir::Transparent);

    if ($c == $self->{'m_mainChart'}) {
        $self->configureYAxis($c->yAxis2(), $height);
        my $topMargin = $c->getDrawArea()->getHeight() - $self->{'m_topMargin'} -
            $self->{'m_bottomMargin'} - $height + $self->{'m_yAxisMargin'};
        if ($topMargin < 0) {
            $topMargin = 0;
        }
        $c->yAxis2()->setTopMargin($topMargin);
        $barLayer->setUseYAxis2();
    }

    my $a = $c->yAxis2();
    if ($c != $self->{'m_mainChart'}) {
        $a = $c->yAxis();
    }
    if (new ArrayMath($self->{'m_volData'})->max() < 10) {
        $a->setLabelFormat(sprintf("{value|1}%s", $self->{'m_volUnit'}));
    } else {
        $a->setLabelFormat(sprintf("{value}%s", $self->{'m_volUnit'}));
    }

    my $closeChange = new ArrayMath($self->{'m_closeData'})->delta()->result();
    my $i = $self->lastIndex($self->{'m_volData'});
    my $label = "Vol";
    if ($i >= 0) {
        $label = sprintf("%s: %s%s", $label, $self->formatValue($self->{'m_volData'}->[$i],
            $self->{'m_generalFormat'}), $self->{'m_volUnit'});
        $closeChange->[0] = 0;
    }

    my $upDS = $barLayer->addDataSet(new ArrayMath($self->{'m_volData'})->selectGTZ($closeChange
        )->result(), $upColor);
    my $dnDS = $barLayer->addDataSet(new ArrayMath($self->{'m_volData'})->selectLTZ($closeChange
        )->result(), $downColor);
    my $flatDS = $barLayer->addDataSet(new ArrayMath($self->{'m_volData'})->selectEQZ($closeChange
        )->result(), $flatColor);

    if (($i < 0) || ($closeChange->[$i] == 0) || ($closeChange->[$i] == $perlchartdir::NoValue)) {
        $flatDS->setDataName($label);
    } elsif ($closeChange->[$i] > 0) {
        $upDS->setDataName($label);
    } else {
        $dnDS->setDataName($label);
    }

    return $barLayer;
}

#/ <summary>
#/ Add a blank indicator chart to the finance chart. Used internally to add other indicators.
#/ Override to change the default formatting (eg. axis fonts, etc.) of the various indicators.
#/ </summary>
#/ <param name="height">The height of the chart in pixels.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addIndicator
{
    my ($self, $height) = @_;
    #create a new chart object
    my $ret = new XYChart($self->{'m_totalWidth'}, $height + $self->{'m_topMargin'} +
        $self->{'m_bottomMargin'}, $perlchartdir::Transparent);
    $ret->setTrimData($self->{'m_extraPoints'});

    if (defined($self->{'m_currentChart'})) {
        #if there is a chart before the newly created chart, disable its x-axis, and copy
        #its x-axis labels to the new chart
        $self->{'m_currentChart'}->xAxis()->setColors($perlchartdir::Transparent,
            $perlchartdir::Transparent);
        $ret->xAxis()->copyAxis($self->{'m_currentChart'}->xAxis());

        #add chart to MultiChart and update the total height
        $self->addChart(0, $self->{'m_totalHeight'} + $self->{'m_plotAreaGap'}, $ret);
        $self->{'m_totalHeight'} = $self->{'m_totalHeight'} + $height + 1 + $self->{'m_plotAreaGap'}
            ;
    } else {
        #no existing chart - create the x-axis labels from scratch
        $self->setXLabels($ret->xAxis());

        #add chart to MultiChart and update the total height
        $self->addChart(0, $self->{'m_totalHeight'}, $ret);
        $self->{'m_totalHeight'} = $self->{'m_totalHeight'} + $height + 1;
    }

    #the newly created chart becomes the current chart
    $self->{'m_currentChart'} = $ret;

    #update the size
    $self->setSize($self->{'m_totalWidth'}, $self->{'m_totalHeight'} + $self->{'m_topMargin'} +
        $self->{'m_bottomMargin'});

    #configure the plot area
    $ret->setPlotArea($self->{'m_leftMargin'}, $self->{'m_topMargin'}, $self->{'m_totalWidth'} -
        $self->{'m_leftMargin'} - $self->{'m_rightMargin'}, $height, $self->{'m_plotAreaBgColor'},
        -1, $self->{'m_plotAreaBorder'})->setGridColor($self->{'m_majorHGridColor'},
        $self->{'m_majorVGridColor'}, $self->{'m_minorHGridColor'}, $self->{'m_minorVGridColor'});
    $ret->setAntiAlias($self->{'m_antiAlias'});

    #configure legend box
    my $box = $ret->addLegend($self->{'m_leftMargin'}, $self->{'m_topMargin'}, 0,
        $self->{'m_legendFont'}, $self->{'m_legendFontSize'});
    $box->setFontColor($self->{'m_legendFontColor'});
    $box->setBackground($self->{'m_legendBgColor'});
    $box->setMargin2(5, 0, 2, 1);
    $box->setSize($self->{'m_totalWidth'} - $self->{'m_leftMargin'} - $self->{'m_rightMargin'} + 1,
        0);

    #configure x-axis
    my $a = $ret->xAxis();
    $a->setIndent(1);
    $a->setTickLength(2, 0);
    $a->setColors($perlchartdir::Transparent, $self->{'m_xAxisFontColor'},
        $self->{'m_xAxisFontColor'}, $self->{'m_xAxisFontColor'});
    $a->setLabelStyle($self->{'m_xAxisFont'}, $self->{'m_xAxisFontSize'},
        $self->{'m_xAxisFontColor'}, $self->{'m_xAxisFontAngle'});

    #configure y-axis
    $ret->setYAxisOnRight($self->{'m_axisOnRight'});
    $self->configureYAxis($ret->yAxis(), $height);

    return $ret;
}

sub configureYAxis
{
    my ($self, $a, $height) = @_;
    $a->setAutoScale(0, 0.05, 0);
    if ($height < 100) {
        $a->setTickDensity(15);
    }
    $a->setMargin($self->{'m_yAxisMargin'});
    $a->setLabelStyle($self->{'m_yAxisFont'}, $self->{'m_yAxisFontSize'},
        $self->{'m_yAxisFontColor'}, 0);
    $a->setTickLength(-4, -2);
    $a->setColors($perlchartdir::Transparent, $self->{'m_yAxisFontColor'},
        $self->{'m_yAxisFontColor'}, $self->{'m_yAxisFontColor'});
}

#/ <summary>
#/ Add a generic line indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="data">The data series of the indicator line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="name">The name of the indicator.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addLineIndicator
{
    my ($self, $height, $data, $color, $name) = @_;
    my $c = $self->addIndicator($height);
    $self->addLineIndicator2($c, $data, $color, $name);
    return $c;
}

#/ <summary>
#/ Add a line to an existing indicator chart.
#/ </summary>
#/ <param name="c">The indicator chart to add the line to.</param>
#/ <param name="data">The data series of the indicator line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="name">The name of the indicator.</param>
#/ <returns>The LineLayer object representing the line created.</returns>
sub addLineIndicator2
{
    my ($self, $c, $data, $color, $name) = @_;
    return $c->addLineLayer($data, $color, $self->formatIndicatorLabel($name, $data));
}

#/ <summary>
#/ Add a generic bar indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="data">The data series of the indicator bars.</param>
#/ <param name="color">The color of the indicator bars.</param>
#/ <param name="name">The name of the indicator.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addBarIndicator
{
    my ($self, $height, $data, $color, $name) = @_;
    my $c = $self->addIndicator($height);
    $self->addBarIndicator2($c, $data, $color, $name);
    return $c;
}

#/ <summary>
#/ Add a bar layer to an existing indicator chart.
#/ </summary>
#/ <param name="c">The indicator chart to add the bar layer to.</param>
#/ <param name="data">The data series of the indicator bars.</param>
#/ <param name="color">The color of the indicator bars.</param>
#/ <param name="name">The name of the indicator.</param>
#/ <returns>The BarLayer object representing the bar layer created.</returns>
sub addBarIndicator2
{
    my ($self, $c, $data, $color, $name) = @_;
    my $layer = $c->addBarLayer($data, $color, $self->formatIndicatorLabel($name, $data));
    $layer->setBorderColor($perlchartdir::Transparent);
    return $layer;
}

#/ <summary>
#/ Add an upper/lower threshold range to an existing indicator chart.
#/ </summary>
#/ <param name="c">The indicator chart to add the threshold range to.</param>
#/ <param name="layer">The line layer that the threshold range applies to.</param>
#/ <param name="topRange">The upper threshold.</param>
#/ <param name="topColor">The color to fill the region of the line that is above the
#/ upper threshold.</param>
#/ <param name="bottomRange">The lower threshold.</param>
#/ <param name="bottomColor">The color to fill the region of the line that is below
#/ the lower threshold.</param>
sub addThreshold
{
    my ($self, $c, $layer, $topRange, $topColor, $bottomRange, $bottomColor) = @_;
    my $topMark = $c->yAxis()->addMark($topRange, $topColor, $self->formatValue($topRange,
        $self->{'m_generalFormat'}));
    my $bottomMark = $c->yAxis()->addMark($bottomRange, $bottomColor, $self->formatValue(
        $bottomRange, $self->{'m_generalFormat'}));

    $c->addInterLineLayer($layer->getLine(), $topMark->getLine(), $topColor,
        $perlchartdir::Transparent);
    $c->addInterLineLayer($layer->getLine(), $bottomMark->getLine(), $perlchartdir::Transparent,
        $bottomColor);
}

sub formatIndicatorLabel
{
    my ($self, $name, $data) = @_;
    my $i = $self->lastIndex($data);
    if (!defined($name)) {
        return $name;
    }
    if (($name eq "") || ($i < 0)) {
        return $name;
    }
    my $ret = sprintf("%s: %s", $name, $self->formatValue($data->[$i], $self->{'m_generalFormat'}));
    return $ret;
}

#/ <summary>
#/ Add an Accumulation/Distribution indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addAccDist
{
    my ($self, $height, $color) = @_;
    #Close Location Value = ((C - L) - (H - C)) / (H - L)
    #Accumulation Distribution Line = Accumulation of CLV * volume
    my $range = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->result();
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->mul(2)->sub(
        $self->{'m_lowData'})->sub($self->{'m_highData'})->mul($self->{'m_volData'})->financeDiv(
        $range, 0)->acc()->result(), $color, "Accumulation/Distribution");
}

sub computeAroonUp
{
    my ($self, $period) = @_;
    my $aroonUp = [(0) x scalar(@{$self->{'m_highData'}})];
    for(my $i = 0; $i < scalar(@{$self->{'m_highData'}}); ++$i) {
        my $highValue = $self->{'m_highData'}->[$i];
        if ($highValue == $perlchartdir::NoValue) {
            $aroonUp->[$i] = $perlchartdir::NoValue;
        } else {
            my $currentIndex = $i;
            my $highCount = $period;
            my $count = $period;

            while (($count > 0) && ($currentIndex >= $count)) {
                $currentIndex = $currentIndex - 1;
                my $currentValue = $self->{'m_highData'}->[$currentIndex];
                if ($currentValue != $perlchartdir::NoValue) {
                    $count = $count - 1;
                    if ($currentValue > $highValue) {
                        $highValue = $currentValue;
                        $highCount = $count;
                    }
                }
            }

            if ($count > 0) {
                $aroonUp->[$i] = $perlchartdir::NoValue;
            } else {
                $aroonUp->[$i] = $highCount * 100.0 / $period;
            }
        }
    }

    return $aroonUp;
}

sub computeAroonDn
{
    my ($self, $period) = @_;
    my $aroonDn = [(0) x scalar(@{$self->{'m_lowData'}})];
    for(my $i = 0; $i < scalar(@{$self->{'m_lowData'}}); ++$i) {
        my $lowValue = $self->{'m_lowData'}->[$i];
        if ($lowValue == $perlchartdir::NoValue) {
            $aroonDn->[$i] = $perlchartdir::NoValue;
        } else {
            my $currentIndex = $i;
            my $lowCount = $period;
            my $count = $period;

            while (($count > 0) && ($currentIndex >= $count)) {
                $currentIndex = $currentIndex - 1;
                my $currentValue = $self->{'m_lowData'}->[$currentIndex];
                if ($currentValue != $perlchartdir::NoValue) {
                    $count = $count - 1;
                    if ($currentValue < $lowValue) {
                        $lowValue = $currentValue;
                        $lowCount = $count;
                    }
                }
            }

            if ($count > 0) {
                $aroonDn->[$i] = $perlchartdir::NoValue;
            } else {
                $aroonDn->[$i] = $lowCount * 100.0 / $period;
            }
        }
    }

    return $aroonDn;
}

#/ <summary>
#/ Add an Aroon Up/Down indicators chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicators.</param>
#/ <param name="upColor">The color of the Aroon Up indicator line.</param>
#/ <param name="downColor">The color of the Aroon Down indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addAroon
{
    my ($self, $height, $period, $upColor, $downColor) = @_;
    my $c = $self->addIndicator($height);
    $self->addLineIndicator2($c, $self->computeAroonUp($period), $upColor, "Aroon Up");
    $self->addLineIndicator2($c, $self->computeAroonDn($period), $downColor, "Aroon Down");
    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add an Aroon Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addAroonOsc
{
    my ($self, $height, $period, $color) = @_;
    my $label = "Aroon Oscillator ($period)";
    my $c = $self->addLineIndicator($height, new ArrayMath($self->computeAroonUp($period))->sub(
        $self->computeAroonDn($period))->result(), $color, $label);
    $c->yAxis()->setLinearScale(-100, 100);
    return $c;
}

sub computeTrueRange
{
    my ($self) = @_;
    my $previousClose = new ArrayMath($self->{'m_closeData'})->shift()->result();
    my $ret = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->result();
    my $temp = 0;

    for(my $i = 0; $i < scalar(@{$self->{'m_highData'}}); ++$i) {
        if (($ret->[$i] != $perlchartdir::NoValue) && ($previousClose->[$i] !=
            $perlchartdir::NoValue)) {
            $temp = abs($self->{'m_highData'}->[$i] - $previousClose->[$i]);
            if ($temp > $ret->[$i]) {
                $ret->[$i] = $temp;
            }
            $temp = abs($previousClose->[$i] - $self->{'m_lowData'}->[$i]);
            if ($temp > $ret->[$i]) {
                $ret->[$i] = $temp;
            }
        }
    }

    return $ret;
}

#/ <summary>
#/ Add an Average Directional Index indicators chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="posColor">The color of the Positive Directional Index line.</param>
#/ <param name="negColor">The color of the Negatuve Directional Index line.</param>
#/ <param name="color">The color of the Average Directional Index line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addADX
{
    my ($self, $height, $period, $posColor, $negColor, $color) = @_;
    #pos/neg directional movement
    my $pos = new ArrayMath($self->{'m_highData'})->delta()->selectGTZ();
    my $neg = new ArrayMath($self->{'m_lowData'})->delta()->mul(-1)->selectGTZ();
    my $delta = new ArrayMath($pos->result())->sub($neg->result())->result();
    $pos->selectGTZ($delta);
    $neg->selectLTZ($delta);

    #pos/neg directional index
    my $tr = $self->computeTrueRange();
    $pos->financeDiv($tr, 0.25)->mul(100)->expAvg(2.0 / ($period + 1));
    $neg->financeDiv($tr, 0.25)->mul(100)->expAvg(2.0 / ($period + 1));

    #directional movement index ??? what happen if division by zero???
    my $totalDM = new ArrayMath($pos->result())->add($neg->result())->result();
    my $dx = new ArrayMath($pos->result())->sub($neg->result())->abs()->financeDiv($totalDM, 0
        )->mul(100)->expAvg(2.0 / ($period + 1));

    my $c = $self->addIndicator($height);
    my $label1 = "+DI ($period)";
    my $label2 = "-DI ($period)";
    my $label3 = "ADX ($period)";
    $self->addLineIndicator2($c, $pos->result(), $posColor, $label1);
    $self->addLineIndicator2($c, $neg->result(), $negColor, $label2);
    $self->addLineIndicator2($c, $dx->result(), $color, $label3);
    return $c;
}

#/ <summary>
#/ Add an Average True Range indicators chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color1">The color of the True Range line.</param>
#/ <param name="color2">The color of the Average True Range line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addATR
{
    my ($self, $height, $period, $color1, $color2) = @_;
    my $trueRange = $self->computeTrueRange();
    my $c = $self->addLineIndicator($height, $trueRange, $color1, "True Range");
    my $label = "Average True Range ($period)";
    $self->addLineIndicator2($c, new ArrayMath($trueRange)->expAvg(2.0 / ($period + 1))->result(),
        $color2, $label);
    return $c;
}

#/ <summary>
#/ Add a Bollinger Band Width indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="width">The band width to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addBollingerWidth
{
    my ($self, $height, $period, $width, $color) = @_;
    my $label = "Bollinger Width ($period, $width)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->movStdDev($period
        )->mul($width * 2)->result(), $color, $label);
}

#/ <summary>
#/ Add a Community Channel Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addCCI
{
    my ($self, $height, $period, $color, $range, $upColor, $downColor) = @_;
    #typical price
    my $tp = new ArrayMath($self->{'m_highData'})->add($self->{'m_lowData'})->add(
        $self->{'m_closeData'})->div(3)->result();

    #simple moving average of typical price
    my $smvtp = new ArrayMath($tp)->movAvg($period)->result();

    #compute mean deviation
    my $movMeanDev = [(0) x scalar(@$smvtp)];
    for(my $i = 0; $i < scalar(@$smvtp); ++$i) {
        my $avg = $smvtp->[$i];
        if ($avg == $perlchartdir::NoValue) {
            $movMeanDev->[$i] = $perlchartdir::NoValue;
        } else {
            my $currentIndex = $i;
            my $count = $period - 1;
            my $acc = 0;

            while (($count > 0) && ($currentIndex >= $count)) {
                $currentIndex = $currentIndex - 1;
                my $currentValue = $tp->[$currentIndex];
                if ($currentValue != $perlchartdir::NoValue) {
                    $count = $count - 1;
                    $acc = $acc + abs($avg - $currentValue);
                }
            }

            if ($count > 0) {
                $movMeanDev->[$i] = $perlchartdir::NoValue;
            } else {
                $movMeanDev->[$i] = $acc / $period;
            }
        }
    }

    my $c = $self->addIndicator($height);
    my $label = "CCI ($period)";
    my $layer = $self->addLineIndicator2($c, new ArrayMath($tp)->sub($smvtp)->financeDiv(
        $movMeanDev, 0)->div(0.015)->result(), $color, $label);
    $self->addThreshold($c, $layer, $range, $upColor, -$range, $downColor);
    return $c;
}

#/ <summary>
#/ Add a Chaikin Money Flow indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addChaikinMoneyFlow
{
    my ($self, $height, $period, $color) = @_;
    my $range = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->result();
    my $volAvg = new ArrayMath($self->{'m_volData'})->movAvg($period)->result();
    my $label = "Chaikin Money Flow ($period)";
    return $self->addBarIndicator($height, new ArrayMath($self->{'m_closeData'})->mul(2)->sub(
        $self->{'m_lowData'})->sub($self->{'m_highData'})->mul($self->{'m_volData'})->financeDiv(
        $range, 0)->movAvg($period)->financeDiv($volAvg, 0)->result(), $color, $label);
}

#/ <summary>
#/ Add a Chaikin Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addChaikinOscillator
{
    my ($self, $height, $color) = @_;
    #first compute acc/dist line
    my $range = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->result();
    my $accdist = new ArrayMath($self->{'m_closeData'})->mul(2)->sub($self->{'m_lowData'})->sub(
        $self->{'m_highData'})->mul($self->{'m_volData'})->financeDiv($range, 0)->acc()->result();

    #chaikin osc = exp3(accdist) - exp10(accdist)
    my $expAvg10 = new ArrayMath($accdist)->expAvg(2.0 / (10 + 1))->result();
    return $self->addLineIndicator($height, new ArrayMath($accdist)->expAvg(2.0 / (3 + 1))->sub(
        $expAvg10)->result(), $color, "Chaikin Oscillator");
}

#/ <summary>
#/ Add a Chaikin Volatility indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The period to smooth the range.</param>
#/ <param name="period2">The period to compute the rate of change of the smoothed range.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addChaikinVolatility
{
    my ($self, $height, $period1, $period2, $color) = @_;
    my $label = "Chaikin Volatility ($period1, $period2)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_highData'})->sub(
        $self->{'m_lowData'})->expAvg(2.0 / ($period1 + 1))->rate($period2)->sub(1)->mul(100
        )->result(), $color, $label);
}

#/ <summary>
#/ Add a Close Location Value indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addCLV
{
    my ($self, $height, $color) = @_;
    #Close Location Value = ((C - L) - (H - C)) / (H - L)
    my $range = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->result();
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->mul(2)->sub(
        $self->{'m_lowData'})->sub($self->{'m_highData'})->financeDiv($range, 0)->result(), $color,
        "Close Location Value");
}

#/ <summary>
#/ Add a Detrended Price Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addDPO
{
    my ($self, $height, $period, $color) = @_;
    my $label = "DPO ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->movAvg($period
        )->shift($period / 2 + 1)->sub($self->{'m_closeData'})->mul(-1)->result(), $color, $label);
}

#/ <summary>
#/ Add a Donchian Channel Width indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addDonchianWidth
{
    my ($self, $height, $period, $color) = @_;
    my $label = "Donchian Width ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_highData'})->movMax($period
        )->sub(new ArrayMath($self->{'m_lowData'})->movMin($period)->result())->result(), $color,
        $label);
}

#/ <summary>
#/ Add a Ease of Movement indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to smooth the indicator.</param>
#/ <param name="color1">The color of the indicator line.</param>
#/ <param name="color2">The color of the smoothed indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addEaseOfMovement
{
    my ($self, $height, $period, $color1, $color2) = @_;
    my $boxRatioInverted = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'}
        )->financeDiv($self->{'m_volData'}, 0)->result();
    my $result = new ArrayMath($self->{'m_highData'})->add($self->{'m_lowData'})->div(2)->delta(
        )->mul($boxRatioInverted)->result();

    my $c = $self->addLineIndicator($height, $result, $color1, "EMV");
    my $label = "EMV EMA ($period)";
    $self->addLineIndicator2($c, new ArrayMath($result)->movAvg($period)->result(), $color2, $label)
        ;
    return $c;
}

#/ <summary>
#/ Add a Fast Stochastic indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The period to compute the %K line.</param>
#/ <param name="period2">The period to compute the %D line.</param>
#/ <param name="color1">The color of the %K line.</param>
#/ <param name="color2">The color of the %D line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addFastStochastic
{
    my ($self, $height, $period1, $period2, $color1, $color2) = @_;
    my $movLow = new ArrayMath($self->{'m_lowData'})->movMin($period1)->result();
    my $movRange = new ArrayMath($self->{'m_highData'})->movMax($period1)->sub($movLow)->result();
    my $stochastic = new ArrayMath($self->{'m_closeData'})->sub($movLow)->financeDiv($movRange, 0.5
        )->mul(100)->result();

    my $label1 = "Fast Stochastic %K ($period1)";
    my $c = $self->addLineIndicator($height, $stochastic, $color1, $label1);
    my $label2 = "%D ($period2)";
    $self->addLineIndicator2($c, new ArrayMath($stochastic)->movAvg($period2)->result(), $color2,
        $label2);

    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a MACD indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The first moving average period to compute the indicator.</param>
#/ <param name="period2">The second moving average period to compute the indicator.</param>
#/ <param name="period3">The moving average period of the signal line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="signalColor">The color of the signal line.</param>
#/ <param name="divColor">The color of the divergent bars.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addMACD
{
    my ($self, $height, $period1, $period2, $period3, $color, $signalColor, $divColor) = @_;
    my $c = $self->addIndicator($height);

    #MACD is defined as the difference between two exponential averages (typically 12/26 days)
    my $expAvg1 = new ArrayMath($self->{'m_closeData'})->expAvg(2.0 / ($period1 + 1))->result();
    my $macd = new ArrayMath($self->{'m_closeData'})->expAvg(2.0 / ($period2 + 1))->sub($expAvg1
        )->result();

    #Add the MACD line
    my $label1 = "MACD ($period1, $period2)";
    $self->addLineIndicator2($c, $macd, $color, $label1);

    #MACD signal line
    my $macdSignal = new ArrayMath($macd)->expAvg(2.0 / ($period3 + 1))->result();
    my $label2 = "EXP ($period3)";
    $self->addLineIndicator2($c, $macdSignal, $signalColor, $label2);

    #Divergence
    $self->addBarIndicator2($c, new ArrayMath($macd)->sub($macdSignal)->result(), $divColor,
        "Divergence");

    return $c;
}

#/ <summary>
#/ Add a Mass Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addMassIndex
{
    my ($self, $height, $color, $upColor, $downColor) = @_;
    #Mass Index
    my $f = 2.0 / (10);
    my $exp9 = new ArrayMath($self->{'m_highData'})->sub($self->{'m_lowData'})->expAvg($f)->result()
        ;
    my $exp99 = new ArrayMath($exp9)->expAvg($f)->result();

    my $c = $self->addLineIndicator($height, new ArrayMath($exp9)->financeDiv($exp99, 1)->movAvg(25
        )->mul(25)->result(), $color, "Mass Index");
    $c->yAxis()->addMark(27, $upColor);
    $c->yAxis()->addMark(26.5, $downColor);
    return $c;
}

#/ <summary>
#/ Add a Money Flow Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addMFI
{
    my ($self, $height, $period, $color, $range, $upColor, $downColor) = @_;
    #Money Flow Index
    my $typicalPrice = new ArrayMath($self->{'m_highData'})->add($self->{'m_lowData'})->add(
        $self->{'m_closeData'})->div(3)->result();
    my $moneyFlow = new ArrayMath($typicalPrice)->mul($self->{'m_volData'})->result();

    my $selector = new ArrayMath($typicalPrice)->delta()->result();
    my $posMoneyFlow = new ArrayMath($moneyFlow)->selectGTZ($selector)->movAvg($period)->result();
    my $posNegMoneyFlow = new ArrayMath($moneyFlow)->selectLTZ($selector)->movAvg($period)->add(
        $posMoneyFlow)->result();

    my $c = $self->addIndicator($height);
    my $label = "Money Flow Index ($period)";
    my $layer = $self->addLineIndicator2($c, new ArrayMath($posMoneyFlow)->financeDiv(
        $posNegMoneyFlow, 0.5)->mul(100)->result(), $color, $label);
    $self->addThreshold($c, $layer, 50 + $range, $upColor, 50 - $range, $downColor);

    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a Momentum indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addMomentum
{
    my ($self, $height, $period, $color) = @_;
    my $label = "Momentum ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->delta($period
        )->result(), $color, $label);
}

#/ <summary>
#/ Add a Negative Volume Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the signal line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="signalColor">The color of the signal line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addNVI
{
    my ($self, $height, $period, $color, $signalColor) = @_;
    my $nvi = [(0) x scalar(@{$self->{'m_volData'}})];

    my $previousNVI = 100;
    my $previousVol = $perlchartdir::NoValue;
    my $previousClose = $perlchartdir::NoValue;
    for(my $i = 0; $i < scalar(@{$self->{'m_volData'}}); ++$i) {
        if ($self->{'m_volData'}->[$i] == $perlchartdir::NoValue) {
            $nvi->[$i] = $perlchartdir::NoValue;
        } else {
            if (($previousVol != $perlchartdir::NoValue) && ($self->{'m_volData'}->[$i] <
                $previousVol) && ($previousClose != $perlchartdir::NoValue) && (
                $self->{'m_closeData'}->[$i] != $perlchartdir::NoValue)) {
                $nvi->[$i] = $previousNVI + $previousNVI * ($self->{'m_closeData'}->[$i] -
                    $previousClose) / $previousClose;
            } else {
                $nvi->[$i] = $previousNVI;
            }

            $previousNVI = $nvi->[$i];
            $previousVol = $self->{'m_volData'}->[$i];
            $previousClose = $self->{'m_closeData'}->[$i];
        }
    }

    my $c = $self->addLineIndicator($height, $nvi, $color, "NVI");
    if (scalar(@$nvi) > $period) {
        my $label = "NVI SMA ($period)";
        $self->addLineIndicator2($c, new ArrayMath($nvi)->movAvg($period)->result(), $signalColor,
            $label);
    }
    return $c;
}

#/ <summary>
#/ Add an On Balance Volume indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addOBV
{
    my ($self, $height, $color) = @_;
    my $closeChange = new ArrayMath($self->{'m_closeData'})->delta()->result();
    my $upVolume = new ArrayMath($self->{'m_volData'})->selectGTZ($closeChange)->result();
    my $downVolume = new ArrayMath($self->{'m_volData'})->selectLTZ($closeChange)->result();

    return $self->addLineIndicator($height, new ArrayMath($upVolume)->sub($downVolume)->acc(
        )->result(), $color, "OBV");
}

#/ <summary>
#/ Add a Performance indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addPerformance
{
    my ($self, $height, $color) = @_;
    my $closeValue = $self->firstCloseValue();
    if ($closeValue != $perlchartdir::NoValue) {
        return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->mul(100 /
            $closeValue)->sub(100)->result(), $color, "Performance");
    } else {
        #chart is empty !!!
        return $self->addIndicator($height);
    }
}

#/ <summary>
#/ Add a Percentage Price Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The first moving average period to compute the indicator.</param>
#/ <param name="period2">The second moving average period to compute the indicator.</param>
#/ <param name="period3">The moving average period of the signal line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="signalColor">The color of the signal line.</param>
#/ <param name="divColor">The color of the divergent bars.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addPPO
{
    my ($self, $height, $period1, $period2, $period3, $color, $signalColor, $divColor) = @_;
    my $expAvg1 = new ArrayMath($self->{'m_closeData'})->expAvg(2.0 / ($period1 + 1))->result();
    my $expAvg2 = new ArrayMath($self->{'m_closeData'})->expAvg(2.0 / ($period2 + 1))->result();
    my $ppo = new ArrayMath($expAvg2)->sub($expAvg1)->financeDiv($expAvg2, 0)->mul(100);
    my $ppoSignal = new ArrayMath($ppo->result())->expAvg(2.0 / ($period3 + 1))->result();

    my $label1 = "PPO ($period1, $period2)";
    my $label2 = "EMA ($period3)";
    my $c = $self->addLineIndicator($height, $ppo->result(), $color, $label1);
    $self->addLineIndicator2($c, $ppoSignal, $signalColor, $label2);
    $self->addBarIndicator2($c, $ppo->sub($ppoSignal)->result(), $divColor, "Divergence");
    return $c;
}

#/ <summary>
#/ Add a Positive Volume Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the signal line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="signalColor">The color of the signal line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addPVI
{
    my ($self, $height, $period, $color, $signalColor) = @_;
    #Positive Volume Index
    my $pvi = [(0) x scalar(@{$self->{'m_volData'}})];

    my $previousPVI = 100;
    my $previousVol = $perlchartdir::NoValue;
    my $previousClose = $perlchartdir::NoValue;
    for(my $i = 0; $i < scalar(@{$self->{'m_volData'}}); ++$i) {
        if ($self->{'m_volData'}->[$i] == $perlchartdir::NoValue) {
            $pvi->[$i] = $perlchartdir::NoValue;
        } else {
            if (($previousVol != $perlchartdir::NoValue) && ($self->{'m_volData'}->[$i] >
                $previousVol) && ($previousClose != $perlchartdir::NoValue) && (
                $self->{'m_closeData'}->[$i] != $perlchartdir::NoValue)) {
                $pvi->[$i] = $previousPVI + $previousPVI * ($self->{'m_closeData'}->[$i] -
                    $previousClose) / $previousClose;
            } else {
                $pvi->[$i] = $previousPVI;
            }

            $previousPVI = $pvi->[$i];
            $previousVol = $self->{'m_volData'}->[$i];
            $previousClose = $self->{'m_closeData'}->[$i];
        }
    }

    my $c = $self->addLineIndicator($height, $pvi, $color, "PVI");
    if (scalar(@$pvi) > $period) {
        my $label = "PVI SMA ($period)";
        $self->addLineIndicator2($c, new ArrayMath($pvi)->movAvg($period)->result(), $signalColor,
            $label);
    }
    return $c;
}

#/ <summary>
#/ Add a Percentage Volume Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The first moving average period to compute the indicator.</param>
#/ <param name="period2">The second moving average period to compute the indicator.</param>
#/ <param name="period3">The moving average period of the signal line.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="signalColor">The color of the signal line.</param>
#/ <param name="divColor">The color of the divergent bars.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addPVO
{
    my ($self, $height, $period1, $period2, $period3, $color, $signalColor, $divColor) = @_;
    my $expAvg1 = new ArrayMath($self->{'m_volData'})->expAvg(2.0 / ($period1 + 1))->result();
    my $expAvg2 = new ArrayMath($self->{'m_volData'})->expAvg(2.0 / ($period2 + 1))->result();
    my $pvo = new ArrayMath($expAvg2)->sub($expAvg1)->financeDiv($expAvg2, 0)->mul(100);
    my $pvoSignal = new ArrayMath($pvo->result())->expAvg(2.0 / ($period3 + 1))->result();

    my $label1 = "PVO ($period1, $period2)";
    my $label2 = "EMA ($period3)";
    my $c = $self->addLineIndicator($height, $pvo->result(), $color, $label1);
    $self->addLineIndicator2($c, $pvoSignal, $signalColor, $label2);
    $self->addBarIndicator2($c, $pvo->sub($pvoSignal)->result(), $divColor, "Divergence");
    return $c;
}

#/ <summary>
#/ Add a Price Volumne Trend indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addPVT
{
    my ($self, $height, $color) = @_;
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->rate()->sub(1
        )->mul($self->{'m_volData'})->acc()->result(), $color, "PVT");
}

#/ <summary>
#/ Add a Rate of Change indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addROC
{
    my ($self, $height, $period, $color) = @_;
    my $label = "ROC ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->rate($period
        )->sub(1)->mul(100)->result(), $color, $label);
}

sub RSIMovAvg
{
    my ($self, $data, $period) = @_;
    #The "moving average" in classical RSI is based on a formula that mixes simple
    #and exponential moving averages.

    if ($period <= 0) {
        $period = 1;
    }

    my $count = 0;
    my $acc = 0;

    for(my $i = 0; $i < scalar(@$data); ++$i) {
        if (abs($data->[$i] / $perlchartdir::NoValue - 1) > 1e-005) {
            $count = $count + 1;
            $acc = $acc + $data->[$i];
            if ($count < $period) {
                $data->[$i] = $perlchartdir::NoValue;
            } else {
                $data->[$i] = $acc / $period;
                $acc = $data->[$i] * ($period - 1);
            }
        }
    }

    return $data;
}

sub computeRSI
{
    my ($self, $period) = @_;
    #RSI is defined as the average up changes for the last 14 days, divided by the
    #average absolute changes for the last 14 days, expressed as a percentage.

    my $absChange = $self->RSIMovAvg(new ArrayMath($self->{'m_closeData'})->delta()->abs()->result(
        ), $period);
    my $absUpChange = $self->RSIMovAvg(new ArrayMath($self->{'m_closeData'})->delta()->selectGTZ(
        )->result(), $period);
    return new ArrayMath($absUpChange)->financeDiv($absChange, 0.5)->mul(100)->result();
}

#/ <summary>
#/ Add a Relative Strength Index indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addRSI
{
    my ($self, $height, $period, $color, $range, $upColor, $downColor) = @_;
    my $c = $self->addIndicator($height);
    my $label = "RSI ($period)";
    my $layer = $self->addLineIndicator2($c, $self->computeRSI($period), $color, $label);

    #Add range if given
    if (($range > 0) && ($range < 50)) {
        $self->addThreshold($c, $layer, 50 + $range, $upColor, 50 - $range, $downColor);
    }
    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a Slow Stochastic indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The period to compute the %K line.</param>
#/ <param name="period2">The period to compute the %D line.</param>
#/ <param name="color1">The color of the %K line.</param>
#/ <param name="color2">The color of the %D line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addSlowStochastic
{
    my ($self, $height, $period1, $period2, $color1, $color2) = @_;
    my $movLow = new ArrayMath($self->{'m_lowData'})->movMin($period1)->result();
    my $movRange = new ArrayMath($self->{'m_highData'})->movMax($period1)->sub($movLow)->result();
    my $stochastic = new ArrayMath($self->{'m_closeData'})->sub($movLow)->financeDiv($movRange, 0.5
        )->mul(100)->movAvg(3);

    my $label1 = "Slow Stochastic %K ($period1)";
    my $label2 = "%D ($period2)";
    my $c = $self->addLineIndicator($height, $stochastic->result(), $color1, $label1);
    $self->addLineIndicator2($c, $stochastic->movAvg($period2)->result(), $color2, $label2);

    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a Moving Standard Deviation indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addStdDev
{
    my ($self, $height, $period, $color) = @_;
    my $label = "Moving StdDev ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->movStdDev($period
        )->result(), $color, $label);
}

#/ <summary>
#/ Add a Stochastic RSI indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addStochRSI
{
    my ($self, $height, $period, $color, $range, $upColor, $downColor) = @_;
    my $rsi = $self->computeRSI($period);
    my $movLow = new ArrayMath($rsi)->movMin($period)->result();
    my $movRange = new ArrayMath($rsi)->movMax($period)->sub($movLow)->result();

    my $c = $self->addIndicator($height);
    my $label = "StochRSI ($period)";
    my $layer = $self->addLineIndicator2($c, new ArrayMath($rsi)->sub($movLow)->financeDiv(
        $movRange, 0.5)->mul(100)->result(), $color, $label);

    #Add range if given
    if (($range > 0) && ($range < 50)) {
        $self->addThreshold($c, $layer, 50 + $range, $upColor, 50 - $range, $downColor);
    }
    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a TRIX indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addTRIX
{
    my ($self, $height, $period, $color) = @_;
    my $f = 2.0 / ($period + 1);
    my $label = "TRIX ($period)";
    return $self->addLineIndicator($height, new ArrayMath($self->{'m_closeData'})->expAvg($f
        )->expAvg($f)->expAvg($f)->rate()->sub(1)->mul(100)->result(), $color, $label);
}

sub computeTrueLow
{
    my ($self) = @_;
    #the lower of today's low or yesterday's close.
    my $previousClose = new ArrayMath($self->{'m_closeData'})->shift()->result();
    my $ret = [(0) x scalar(@{$self->{'m_lowData'}})];
    for(my $i = 0; $i < scalar(@{$self->{'m_lowData'}}); ++$i) {
        if (($self->{'m_lowData'}->[$i] != $perlchartdir::NoValue) && ($previousClose->[$i] !=
            $perlchartdir::NoValue)) {
            if ($self->{'m_lowData'}->[$i] < $previousClose->[$i]) {
                $ret->[$i] = $self->{'m_lowData'}->[$i];
            } else {
                $ret->[$i] = $previousClose->[$i];
            }
        } else {
            $ret->[$i] = $perlchartdir::NoValue;
        }
    }

    return $ret;
}

#/ <summary>
#/ Add an Ultimate Oscillator indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period1">The first moving average period to compute the indicator.</param>
#/ <param name="period2">The second moving average period to compute the indicator.</param>
#/ <param name="period3">The third moving average period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addUltimateOscillator
{
    my ($self, $height, $period1, $period2, $period3, $color, $range, $upColor, $downColor) = @_;
    my $trueLow = $self->computeTrueLow();
    my $buyingPressure = new ArrayMath($self->{'m_closeData'})->sub($trueLow)->result();
    my $trueRange = $self->computeTrueRange();

    my $rawUO1 = new ArrayMath($buyingPressure)->movAvg($period1)->financeDiv(new ArrayMath(
        $trueRange)->movAvg($period1)->result(), 0.5)->mul(4)->result();
    my $rawUO2 = new ArrayMath($buyingPressure)->movAvg($period2)->financeDiv(new ArrayMath(
        $trueRange)->movAvg($period2)->result(), 0.5)->mul(2)->result();
    my $rawUO3 = new ArrayMath($buyingPressure)->movAvg($period3)->financeDiv(new ArrayMath(
        $trueRange)->movAvg($period3)->result(), 0.5)->mul(1)->result();

    my $c = $self->addIndicator($height);
    my $label = "Ultimate Oscillator ($period1, $period2, $period3)";
    my $layer = $self->addLineIndicator2($c, new ArrayMath($rawUO1)->add($rawUO2)->add($rawUO3
        )->mul(100.0 / 7)->result(), $color, $label);
    $self->addThreshold($c, $layer, 50 + $range, $upColor, 50 - $range, $downColor);

    $c->yAxis()->setLinearScale(0, 100);
    return $c;
}

#/ <summary>
#/ Add a Volume indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="upColor">The color to used on an 'up' day. An 'up' day is a day where
#/ the closing price is higher than that of the previous day.</param>
#/ <param name="downColor">The color to used on a 'down' day. A 'down' day is a day
#/ where the closing price is lower than that of the previous day.</param>
#/ <param name="flatColor">The color to used on a 'flat' day. A 'flat' day is a day
#/ where the closing price is the same as that of the previous day.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addVolIndicator
{
    my ($self, $height, $upColor, $downColor, $flatColor) = @_;
    my $c = $self->addIndicator($height);
    $self->addVolBars2($c, $height, $upColor, $downColor, $flatColor);
    return $c;
}

#/ <summary>
#/ Add a William %R indicator chart.
#/ </summary>
#/ <param name="height">The height of the indicator chart in pixels.</param>
#/ <param name="period">The period to compute the indicator.</param>
#/ <param name="color">The color of the indicator line.</param>
#/ <param name="range">The distance beween the middle line and the upper and lower threshold lines.</param>
#/ <param name="upColor">The fill color when the indicator exceeds the upper threshold line.</param>
#/ <param name="downColor">The fill color when the indicator falls below the lower threshold line.</param>
#/ <returns>The XYChart object representing the chart created.</returns>
sub addWilliamR
{
    my ($self, $height, $period, $color, $range, $upColor, $downColor) = @_;
    my $movLow = new ArrayMath($self->{'m_lowData'})->movMin($period)->result();
    my $movHigh = new ArrayMath($self->{'m_highData'})->movMax($period)->result();
    my $movRange = new ArrayMath($movHigh)->sub($movLow)->result();

    my $c = $self->addIndicator($height);
    my $layer = $self->addLineIndicator2($c, new ArrayMath($movHigh)->sub($self->{'m_closeData'}
        )->financeDiv($movRange, 0.5)->mul(-100)->result(), $color, "William %R");
    $self->addThreshold($c, $layer, -50 + $range, $upColor, -50 - $range, $downColor);
    $c->yAxis()->setLinearScale(-100, 0);
    return $c;
}
1;
