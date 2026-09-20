param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Add-Type -AssemblyName System.Drawing

$iconTargets = @{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png' = 20
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png' = 40
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png' = 60
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png' = 29
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png' = 58
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png' = 87
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png' = 40
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png' = 80
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png' = 120
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png' = 120
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png' = 180
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png' = 76
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png' = 152
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png' = 167
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png' = 1024
}

function New-RoundedPath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-AppIcon([int]$size, [string]$path) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $scale = $size / 1024.0
    $graphics.ScaleTransform($scale, $scale)

    $background = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#08111d'))
    $graphics.FillRectangle($background, 0, 0, 1024, 1024)
    $background.Dispose()

    $framePath = New-RoundedPath 40 40 944 944 190
    $frameBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#101e32'))
    $framePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#2a4967'), 8)
    $graphics.FillPath($frameBrush, $framePath)
    $graphics.DrawPath($framePen, $framePath)
    $frameBrush.Dispose(); $framePen.Dispose(); $framePath.Dispose()

    $mazePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#65e5e4'), 58)
    $mazePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $mazePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $mazePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $mazePoints = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(188, 194), [System.Drawing.PointF]::new(516, 194),
        [System.Drawing.PointF]::new(516, 364), [System.Drawing.PointF]::new(278, 364),
        [System.Drawing.PointF]::new(278, 690), [System.Drawing.PointF]::new(710, 690),
        [System.Drawing.PointF]::new(710, 512), [System.Drawing.PointF]::new(850, 512))
    $graphics.DrawLines($mazePen, $mazePoints)
    $mazePen.Dispose()

    $branchPen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#2e93ad'), 28)
    $branchPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $branchPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($branchPen, 278, 364, 188, 364)
    $graphics.DrawLine($branchPen, 710, 690, 710, 826)
    $graphics.DrawLine($branchPen, 710, 826, 850, 826)
    $branchPen.Dispose()

    $shadow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150, 2, 7, 17))
    $graphics.FillEllipse($shadow, 656, 190, 216, 216)
    $shadow.Dispose()
    $ball = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#ffb547'))
    $ballPen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#ffe0a3'), 10)
    $graphics.FillEllipse($ball, 656, 190, 184, 184)
    $graphics.DrawEllipse($ballPen, 656, 190, 184, 184)
    $ball.Dispose(); $ballPen.Dispose()
    $highlight = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(230, 255, 244, 214))
    $graphics.FillEllipse($highlight, 692, 224, 52, 52)
    $highlight.Dispose()
    $ringPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(90, 255, 181, 71), 8)
    $graphics.DrawEllipse($ringPen, 622, 156, 252, 252)
    $ringPen.Dispose()

    $graphics.Dispose()
    $fullPath = Join-Path $ProjectRoot $path
    New-Item -ItemType Directory -Force (Split-Path $fullPath) | Out-Null
    $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

foreach ($target in $iconTargets.GetEnumerator()) {
    New-AppIcon $target.Value $target.Key
}
