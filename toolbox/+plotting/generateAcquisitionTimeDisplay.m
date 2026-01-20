function displayFcn = generateAcquisitionTimeDisplay()
%GENERATEACQUISITIONTIMEDISPLAY Summary of this function goes here
%   Detailed explanation goes here
f = uifigure("Name", "Acquisition Time", "Theme", 'light');
f.Position(3:4) = [300, 100];

gridlayout = uigridlayout(f, [1,1]);
editfield = uieditfield(gridlayout, "Editable", "off", ..., 
    "HorizontalAlignment", 'center', "FontSize", 30);

displayFcn = @(time)updateTimerDisplay(editfield, time);


    function updateTimerDisplay(editfield, time)
        time = seconds(time);
        time.Format = 'hh:mm:ss.S';
        editfield.Value = string(time);

    end
end