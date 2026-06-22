function NFR_GUI()
%NFR_GUI  Nonlinear Fourier Reweighting (NFR) Algorithm - GUI
%
%   Supports: 2D Single Frame, 2D Time Series, 2D Multi-Channel, 3D Stack
%   Compatibility: MATLAB R2017a and later
%
%   Usage: Place NFR_logo.png in the same folder, then run NFR_GUI()

    %% ====================== Shared State ======================
    imgRaw        = [];
    imgResult     = [];
    previewSlice  = [];
    imgType       = '2D';
    k1 = 0.1;   k2 = 0;
    curFrame  = 1;
    numFrames = 1;
    imgM = 0; imgN = 0; imgP = 0;
    cmapName  = 'gray';
    srcFullPath = ''; srcName = ''; srcPath = '';
    chK1 = [];  chK2 = [];
    curCh = 1;
    crossX = 1; crossY = 1;
    procTime = 0;
    allProcessed = false;

    % Discrete k1 slider values (8 values, index 1-8)
    k1Vals = [0.0001, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 1.0];
    k1Idx  = 4; % Default: k1 = 0.1

    % Discrete k2 slider values (9 values, index 1-9)
    k2Vals = [-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1.0];
    k2Idx  = 5; % Default: k2 = 0

    % Filter parameters
    filterOn     = false;        % Default: OFF
    filterType   = 'Gaussian';   % 'Gaussian' or 'Mean'
    filterRadius = 1;            % Default radius = 1, range [0, 5]

    %% ====================== Create Main Figure ======================
    scr = get(0, 'ScreenSize');
    fw = min(1440, round(scr(3) * 0.88));
    fh = min(960,  round(scr(4) * 0.88));

    hFig = figure(...
        'Name',            'NFR - Nonlinear Fourier Reweighting v1.0', ...
        'NumberTitle',     'off', ...
        'MenuBar',         'none', ...
        'ToolBar',         'figure', ...
        'Units',           'pixels', ...
        'Position',        [(scr(3)-fw)/2, (scr(4)-fh)/2, fw, fh], ...
        'Color',           [0.15 0.15 0.17], ...
        'Resize',          'on', ...
        'Visible',         'off', ...
        'WindowScrollWheelFcn', @cbScroll);

    trySetWindowIcon();

    %% ====================== Layout Constants ======================
    TOP_H = 110;   % Increased to fit 100x100 logo
    BOT_H = 180;   % Increased from 140 to add filter row

    %% ====================== Top Panel (Header) ======================
    pTop = uipanel(hFig, 'Units','pixels', ...
        'Position',[0, fh-TOP_H, fw, TOP_H], ...
        'BackgroundColor',[0.10 0.10 0.12], 'BorderType','none');

    % Logo: 100x100
    axLogo = axes('Parent',pTop, 'Units','pixels', 'Position',[5 5 100 100]);
    showLogo(axLogo, 100);

    % Title
    uicontrol(pTop, 'Style','text', ...
        'String','NFR - Nonlinear Fourier Reweighting', ...
        'Units','pixels', 'Position',[115 65 380 35], ...
        'FontSize',15, 'FontWeight','bold', ...
        'ForegroundColor',[0 0.90 1], ...
        'BackgroundColor',[0.10 0.10 0.12], ...
        'HorizontalAlignment','left');

    % Subtitle
    uicontrol(pTop, 'Style','text', ...
        'String','Non-iterative Spectral Reweighting for Microscopy', ...
        'Units','pixels', 'Position',[115 45 380 20], ...
        'FontSize',9, 'FontAngle','italic', ...
        'ForegroundColor',[0.55 0.55 0.58], ...
        'BackgroundColor',[0.10 0.10 0.12], ...
        'HorizontalAlignment','left');

    % Controls row
    makeLabel(pTop, [115 10 80 22], 'Image Type:');
    hPopType = uicontrol(pTop, 'Style','popupmenu', ...
        'String',{'2D Single Frame','2D Time Series', ...
                  '2D Multi-Channel','3D Stack'}, ...
        'Units','pixels', 'Position',[200 12 155 22], ...
        'FontSize',10, 'Callback',@cbTypeChange);

    uicontrol(pTop, 'Style','pushbutton', 'String','Load Image', ...
        'Units','pixels', 'Position',[370 6 115 34], ...
        'FontSize',11, 'FontWeight','bold', ...
        'BackgroundColor',[0.12 0.58 0.95], 'ForegroundColor','w', ...
        'Callback',@cbLoad);

    uicontrol(pTop, 'Style','text', ...
        'String', [char(9889) ' No GPU, Pure CPU Speed!'], ...
        'Units','pixels', 'Position',[500 10 220 22], ...
        'FontSize',10, 'FontWeight','bold', ...
        'ForegroundColor',[0.2 1 0.4], ...
        'BackgroundColor',[0.10 0.10 0.12], ...
        'HorizontalAlignment','left');

    makeLabel(pTop, [730 10 68 22], 'Colormap:');
    hPopCmap = uicontrol(pTop, 'Style','popupmenu', ...
        'String',{'gray','hot','jet','parula','turbo', ...
                  'green','magenta','cyan'}, ...
        'Units','pixels', 'Position',[803 12 100 22], ...
        'FontSize',10, 'Callback',@cbCmap);

    %% ====================== Bottom Panel (Controls) ======================
    pBot = uipanel(hFig, 'Units','pixels', ...
        'Position',[0, 0, fw, BOT_H], ...
        'BackgroundColor',[0.13 0.13 0.15], 'BorderType','none');

    % ---- Row 4: Frame Slider (topmost row in bottom panel) ----
    hLblFrame = uicontrol(pBot, 'Style','text', ...
        'String','Frame: 1 / 1', ...
        'Units','pixels', 'Position',[10 152 130 20], ...
        'FontSize',10, 'ForegroundColor',[0.7 0.7 0.7], ...
        'BackgroundColor',[0.13 0.13 0.15], 'HorizontalAlignment','left');

    hSldFrame = uicontrol(pBot, 'Style','slider', ...
        'Min',1, 'Max',2, 'Value',1, 'SliderStep',[1 1], ...
        'Units','pixels', 'Position',[145 154 fw-320 16], ...
        'Enable','off', 'Callback',@cbFrameSlider);

    hLblCh = uicontrol(pBot, 'Style','text', 'String','Channel:', ...
        'Units','pixels', 'Position',[fw-170 152 65 20], ...
        'FontSize',10, 'ForegroundColor',[0.7 0.7 0.7], ...
        'BackgroundColor',[0.13 0.13 0.15], 'Visible','off');
    hPopCh = uicontrol(pBot, 'Style','popupmenu', 'String',{'Ch 1'}, ...
        'Units','pixels', 'Position',[fw-100 154 90 20], ...
        'FontSize',9, 'Visible','off', 'Callback',@cbChChange);

    % ---- Row 3: k1 Parameter (discrete, 8 values) ----
    makeLabel(pBot, [10 114 28 22], 'k1:', [1 0.85 0.2]);
    hSldK1 = uicontrol(pBot, 'Style','slider', ...
        'Min',1, 'Max',8, 'Value',4, 'SliderStep',[1/7 1/7], ...
        'Units','pixels', 'Position',[42 116 280 16], ...
        'Callback',@cbK1Sld);
    hEdtK1 = uicontrol(pBot, 'Style','edit', 'String','0.1', ...
        'Units','pixels', 'Position',[328 112 78 24], ...
        'FontSize',10, 'Callback',@cbK1Edt, ...
        'TooltipString','k1: amplitude scaling (0, 1]');

    % k1 tick labels
    uicontrol(pBot, 'Style','text', 'String','1e-4', ...
        'Units','pixels', 'Position',[38 98 35 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','left');
    uicontrol(pBot, 'Style','text', 'String','1.0', ...
        'Units','pixels', 'Position',[300 98 28 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','right');

    % ---- Row 3: k2 Parameter (discrete, 9 values) ----
    makeLabel(pBot, [430 114 28 22], 'k2:', [1 0.85 0.2]);
    hSldK2 = uicontrol(pBot, 'Style','slider', ...
        'Min',1, 'Max',9, 'Value',5, 'SliderStep',[1/8 1/8], ...
        'Units','pixels', 'Position',[462 116 280 16], ...
        'Callback',@cbK2Sld);
    hEdtK2 = uicontrol(pBot, 'Style','edit', 'String','0', ...
        'Units','pixels', 'Position',[748 112 78 24], ...
        'FontSize',10, 'Callback',@cbK2Edt, ...
        'TooltipString','k2: log offset [-1, 1]');

    % k2 tick labels
    uicontrol(pBot, 'Style','text', 'String','-1', ...
        'Units','pixels', 'Position',[458 98 20 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','left');
    uicontrol(pBot, 'Style','text', 'String','1.0', ...
        'Units','pixels', 'Position',[720 98 28 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','right');

    % ---- Row 2: Post-Filter Controls ----
    hChkFilter = uicontrol(pBot, 'Style','checkbox', ...
        'String','Post-Filter', ...
        'Units','pixels', 'Position',[10 72 100 22], ...
        'FontSize',10, 'FontWeight','bold', ...
        'ForegroundColor',[0.85 0.55 1.0], ...
        'BackgroundColor',[0.13 0.13 0.15], ...
        'Value',0, 'Callback',@cbFilterToggle, ...
        'TooltipString','Enable/Disable post-processing filter');

    hLblFiltType = uicontrol(pBot, 'Style','text', 'String','Type:', ...
        'Units','pixels', 'Position',[112 72 38 20], ...
        'FontSize',9, 'ForegroundColor',[0.55 0.55 0.58], ...
        'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','right', 'Enable','off');

    hPopFilter = uicontrol(pBot, 'Style','popupmenu', ...
        'String',{'Gaussian','Mean'}, ...
        'Units','pixels', 'Position',[154 74 90 20], ...
        'FontSize',9, 'Enable','off', 'Callback',@cbFilterTypeChange, ...
        'TooltipString','Select filter type: Gaussian (smooth) or Mean (disk/sphere average)');

    hLblFiltR = uicontrol(pBot, 'Style','text', 'String','Radius:', ...
        'Units','pixels', 'Position',[252 72 52 20], ...
        'FontSize',9, 'ForegroundColor',[0.45 0.45 0.48], ...
        'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','right', 'Enable','off');

    hSldFilter = uicontrol(pBot, 'Style','slider', ...
        'Min',0, 'Max',5, 'Value',1, 'SliderStep',[0.02 0.1], ...
        'Units','pixels', 'Position',[308 76 280 16], ...
        'Enable','off', 'Callback',@cbFilterRadiusSld, ...
        'TooltipString','Filter kernel radius (continuous, 0~5)');

    hEdtFilter = uicontrol(pBot, 'Style','edit', 'String','1.00', ...
        'Units','pixels', 'Position',[594 72 60 24], ...
        'FontSize',10, 'Enable','off', 'Callback',@cbFilterRadiusEdt, ...
        'TooltipString','Filter radius value (0 = no filter)');

    % Filter tick labels
    uicontrol(pBot, 'Style','text', 'String','0', ...
        'Units','pixels', 'Position',[305 58 16 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','left');
    uicontrol(pBot, 'Style','text', 'String','5.0', ...
        'Units','pixels', 'Position',[566 58 28 13], 'FontSize',7, ...
        'ForegroundColor',[0.5 0.5 0.5], 'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','right');

    hLblFiltInfo = uicontrol(pBot, 'Style','text', ...
        'String','[Disk/Sphere kernel, not square]', ...
        'Units','pixels', 'Position',[660 72 200 20], ...
        'FontSize',8, 'FontAngle','italic', ...
        'ForegroundColor',[0.45 0.45 0.48], ...
        'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','left');

    % ---- Row 1: Action Buttons and Timing ----
    hBtnProcess = uicontrol(pBot, 'Style','pushbutton', ...
        'String','Process All Frames', ...
        'Units','pixels', 'Position',[10 12 160 40], ...
        'FontSize',11, 'FontWeight','bold', ...
        'BackgroundColor',[0.08 0.72 0.30], 'ForegroundColor','w', ...
        'Callback',@cbProcessAll);

    hBtnSave = uicontrol(pBot, 'Style','pushbutton', ...
        'String','Save Result', ...
        'Units','pixels', 'Position',[180 12 130 40], ...
        'FontSize',11, 'FontWeight','bold', ...
        'BackgroundColor',[0.18 0.50 0.95], 'ForegroundColor','w', ...
        'Callback',@cbSave);

    hLblTime = uicontrol(pBot, 'Style','text', ...
        'String','Processing Time:  --', ...
        'Units','pixels', 'Position',[330 28 700 24], ...
        'FontSize',12, 'FontWeight','bold', ...
        'ForegroundColor',[0 1 0.55], ...
        'BackgroundColor',[0.13 0.13 0.15], ...
        'HorizontalAlignment','left');

    uicontrol(pBot, 'Style','text', ...
        'String','[ Non-iterative | No PSF needed | No GPU needed | Pure CPU speed! ]', ...
        'Units','pixels', 'Position',[330 3 700 16], ...
        'FontSize',9, 'ForegroundColor',[0.40 0.40 0.42], ...
        'BackgroundColor',[0.13 0.13 0.15], 'HorizontalAlignment','left');

    %% ====================== Main Display Panel ======================
    pMain = uipanel(hFig, 'Units','pixels', ...
        'Position',[0, BOT_H, fw, fh-TOP_H-BOT_H], ...
        'BackgroundColor',[0.06 0.06 0.08], 'BorderType','none');

    % ---- 2D mode axes ----
    ax2D_orig = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.01 0.04 0.48 0.90], 'Color',[0 0 0]);
    title(ax2D_orig, 'Original', 'Color','w', 'FontSize',12);
    axis(ax2D_orig, 'image'); set(ax2D_orig,'XTick',[],'YTick',[]);

    ax2D_proc = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.51 0.04 0.48 0.90], 'Color',[0 0 0]);
    title(ax2D_proc, 'NFR Result', 'Color','w', 'FontSize',12);
    axis(ax2D_proc, 'image'); set(ax2D_proc,'XTick',[],'YTick',[]);

    linkaxes([ax2D_orig, ax2D_proc], 'xy');

    % ---- 3D mode axes ----
    ax3O_xy = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.01 0.26 0.31 0.70], 'Color',[0 0 0], 'Visible','off');
    ax3O_yz = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.33 0.26 0.15 0.70], 'Color',[0 0 0], 'Visible','off');
    ax3O_xz = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.01 0.04 0.31 0.20], 'Color',[0 0 0], 'Visible','off');

    ax3P_xy = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.52 0.26 0.31 0.70], 'Color',[0 0 0], 'Visible','off');
    ax3P_yz = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.84 0.26 0.15 0.70], 'Color',[0 0 0], 'Visible','off');
    ax3P_xz = axes('Parent',pMain, 'Units','normalized', ...
        'Position',[0.52 0.04 0.31 0.20], 'Color',[0 0 0], 'Visible','off');

    %% ==================================================================
    %%                        CALLBACK FUNCTIONS
    %% ==================================================================

    function cbTypeChange(~,~)
        types = {'2D','TimeSeries','MultiChannel','3D'};
        imgType = types{get(hPopType, 'Value')};
        doReset();
    end

    function cbLoad(~,~)
        [f, p] = uigetfile({ ...
            '*.tif;*.tiff', 'TIFF files (*.tif, *.tiff)'; ...
            '*.png;*.jpg;*.bmp', 'Other image formats'; ...
            '*.*', 'All files'}, ...
            'Select Image File');
        if isequal(f, 0), return; end

        srcFullPath = fullfile(p, f);
        srcPath = p;
        [~, srcName] = fileparts(f);

        try
            inf = imfinfo(srcFullPath);
        catch ME
            errordlg(['Cannot read file: ' ME.message], 'NFR Error');
            return;
        end
        nf = numel(inf);

        tmp = imread(srcFullPath, 1);
        if size(tmp,3) > 1, tmp = tmp(:,:,1); end
        [M, N] = size(tmp);

        raw = zeros(M, N, nf);
        raw(:,:,1) = im2double(tmp);
        for ii = 2:nf
            t = imread(srcFullPath, ii);
            if size(t,3) > 1, t = t(:,:,1); end
            raw(:,:,ii) = im2double(t);
        end

        imgRaw = raw;
        imgM = M; imgN = N; imgP = nf;
        numFrames = nf;
        allProcessed = false;
        imgResult = [];

        if any(strcmp(imgType, {'TimeSeries','MultiChannel'}))
            curFrame = max(1, round(nf / 2));
        else
            curFrame = 1;
        end

        if nf > 1
            step1 = 1 / (nf - 1);
            set(hSldFrame, 'Min',1, 'Max',nf, 'Value',curFrame, ...
                'SliderStep',[step1, min(10*step1, 1)], 'Enable','on');
        else
            set(hSldFrame, 'Min',1, 'Max',2, 'Value',1, 'Enable','off');
        end
        set(hLblFrame, 'String', sprintf('Frame: %d / %d', curFrame, numFrames));

        if strcmp(imgType, 'MultiChannel')
            chK1 = 0.1 * ones(1, nf);
            chK2 = zeros(1, nf);
            strs = cell(1, nf);
            for cc = 1:nf, strs{cc} = sprintf('Ch %d', cc); end
            set(hPopCh, 'String',strs, 'Value',1, 'Visible','on');
            set(hLblCh, 'Visible','on');
            curCh = 1;
        else
            set(hPopCh, 'Visible','off');
            set(hLblCh, 'Visible','off');
        end

        % Reset k1 and k2 to defaults
        k1 = 0.1;  k1Idx = 4;
        k2 = 0;    k2Idx = 5;
        set(hSldK1, 'Value', k1Idx);
        set(hEdtK1, 'String', '0.1');
        set(hSldK2, 'Value', k2Idx);
        set(hEdtK2, 'String', '0');

        crossX = round(N / 2);
        crossY = round(M / 2);

        doPreview();
        doDisplay();
    end

    % ---- k1 Slider: discrete snap (8 values) ----
    function cbK1Sld(~,~)
        v = max(1, min(8, round(get(hSldK1, 'Value'))));
        set(hSldK1, 'Value', v);
        k1 = k1Vals(v);
        k1Idx = v;
        set(hEdtK1, 'String', formatNum(k1));
        syncMultiChParams();
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbK1Edt(~,~)
        v = str2double(get(hEdtK1, 'String'));
        if isnan(v) || v <= 0 || v > 1
            set(hEdtK1, 'String', formatNum(k1));
            return;
        end
        k1 = v;
        [~, idx] = min(abs(k1Vals - k1));
        k1Idx = idx;
        set(hSldK1, 'Value', idx);
        set(hEdtK1, 'String', formatNum(k1));
        syncMultiChParams();
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    % ---- k2 Slider: discrete snap (9 values) ----
    function cbK2Sld(~,~)
        v = max(1, min(9, round(get(hSldK2, 'Value'))));
        set(hSldK2, 'Value', v);
        k2 = k2Vals(v);
        k2Idx = v;
        set(hEdtK2, 'String', formatNum(k2));
        syncMultiChParams();
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbK2Edt(~,~)
        v = str2double(get(hEdtK2, 'String'));
        if isnan(v) || v < -1 || v > 1
            set(hEdtK2, 'String', formatNum(k2));
            return;
        end
        k2 = v;
        [~, idx] = min(abs(k2Vals - k2));
        k2Idx = idx;
        set(hSldK2, 'Value', idx);
        set(hEdtK2, 'String', formatNum(k2));
        syncMultiChParams();
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    % ---- Filter Callbacks ----
    function cbFilterToggle(~,~)
        filterOn = logical(get(hChkFilter, 'Value'));
        enableStr = boolStr(filterOn);
        set(hPopFilter,  'Enable', enableStr);
        set(hSldFilter,  'Enable', enableStr);
        set(hEdtFilter,  'Enable', enableStr);
        set(hLblFiltType,'Enable', enableStr);
        set(hLblFiltR,   'Enable', enableStr);
        % Filter change requires re-processing
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbFilterTypeChange(~,~)
        types = {'Gaussian','Mean'};
        filterType = types{get(hPopFilter, 'Value')};
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbFilterRadiusSld(~,~)
        filterRadius = get(hSldFilter, 'Value');
        % Round to 2 decimal places for display
        filterRadius = round(filterRadius * 100) / 100;
        set(hSldFilter, 'Value', filterRadius);
        set(hEdtFilter, 'String', sprintf('%.2f', filterRadius));
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbFilterRadiusEdt(~,~)
        v = str2double(get(hEdtFilter, 'String'));
        if isnan(v) || v < 0 || v > 5
            set(hEdtFilter, 'String', sprintf('%.2f', filterRadius));
            return;
        end
        filterRadius = round(v * 100) / 100;
        set(hSldFilter, 'Value', filterRadius);
        set(hEdtFilter, 'String', sprintf('%.2f', filterRadius));
        allProcessed = false;
        doPreview();
        doDisplay();
    end

    function cbCmap(~,~)
        maps = {'gray','hot','jet','parula','turbo','green','magenta','cyan'};
        cmapName = maps{get(hPopCmap, 'Value')};
        doDisplay();
    end

    function cbFrameSlider(~,~)
        curFrame = max(1, min(numFrames, round(get(hSldFrame, 'Value'))));
        set(hSldFrame, 'Value', curFrame);
        set(hLblFrame, 'String', sprintf('Frame: %d / %d', curFrame, numFrames));

        if strcmp(imgType, 'MultiChannel')
            curCh = curFrame;
            set(hPopCh, 'Value', curCh);
            k1 = chK1(curCh);
            k2 = chK2(curCh);
            refreshParamUI();
        end

        doPreview();
        doDisplay();
    end

    function cbChChange(~,~)
        curCh = get(hPopCh, 'Value');
        curFrame = curCh;
        set(hSldFrame, 'Value', curFrame);
        set(hLblFrame, 'String', sprintf('Frame: %d / %d', curFrame, numFrames));
        k1 = chK1(curCh);
        k2 = chK2(curCh);
        refreshParamUI();
        doPreview();
        doDisplay();
    end

    function cbProcessAll(~,~)
        if isempty(imgRaw)
            msgbox('Please load an image first.', 'NFR', 'warn');
            return;
        end

        set(hBtnProcess, 'String','Processing...', 'Enable','off');
        drawnow;

        tic;
        switch imgType
            case '2D'
                imgResult = coreNFR2D(imgRaw(:,:,1), k1, k2);
                if filterOn && filterRadius > 0
                    imgResult = applyFilter2D(imgResult);
                end
            case 'TimeSeries'
                imgResult = zeros(imgM, imgN, numFrames);
                for ii = 1:numFrames
                    frame = coreNFR2D(imgRaw(:,:,ii), k1, k2);
                    if filterOn && filterRadius > 0
                        frame = applyFilter2D(frame);
                    end
                    imgResult(:,:,ii) = frame;
                end
            case 'MultiChannel'
                imgResult = zeros(imgM, imgN, numFrames);
                for ii = 1:numFrames
                    frame = coreNFR2D(imgRaw(:,:,ii), chK1(ii), chK2(ii));
                    if filterOn && filterRadius > 0
                        frame = applyFilter2D(frame);
                    end
                    imgResult(:,:,ii) = frame;
                end
            case '3D'
                imgResult = coreNFR3D(imgRaw, k1, k2);
                if filterOn && filterRadius > 0
                    imgResult = applyFilter3D(imgResult);
                end
        end
        totalTime = toc;
        allProcessed = true;

        switch imgType
            case '2D'
                previewSlice = imgResult;
            case {'TimeSeries','MultiChannel'}
                previewSlice = imgResult(:,:,curFrame);
            case '3D'
                previewSlice = imgResult;
        end

        filtStr = '';
        if filterOn && filterRadius > 0
            filtStr = sprintf(' | %s filter r=%.2f', filterType, filterRadius);
        end
        set(hLblTime, 'String', sprintf( ...
            'DONE: %.4f s total | %d frame(s) | %.4f s/frame%s', ...
            totalTime, numFrames, totalTime/numFrames, filtStr));

        set(hBtnProcess, 'String','Process All Frames', 'Enable','on');
        doDisplay();
    end

    function cbSave(~,~)
        if isempty(imgRaw)
            msgbox('No image loaded.', 'NFR', 'warn');
            return;
        end

        if allProcessed && ~isempty(imgResult)
            dataToSave = imgResult;
        elseif ~isempty(previewSlice)
            dataToSave = previewSlice;
        else
            msgbox('No processed data. Click "Process All Frames" first.', ...
                'NFR', 'warn');
            return;
        end

        k1str = strrep(sprintf('%.4g', k1), '.', 'p');
        k2str = strrep(sprintf('%.4g', k2), '.', 'p');
        k2str = strrep(k2str, '-', 'neg');
        defName = sprintf('%s_NFR_k1_%s_k2_%s.tif', srcName, k1str, k2str);

        [f, p] = uiputfile({'*.tif','TIFF files (*.tif)'}, ...
            'Save NFR Result', fullfile(srcPath, defName));
        if isequal(f, 0), return; end

        outPath = fullfile(p, f);
        nSlices = size(dataToSave, 3);

        for ii = 1:nSlices
            sliceData = dataToSave(:,:,ii);
            sliceData(sliceData < 0) = 0;
            slice16 = uint16(round(sliceData * 65535));
            if ii == 1
                imwrite(slice16, outPath, 'Compression','none');
            else
                imwrite(slice16, outPath, 'WriteMode','append', 'Compression','none');
            end
        end

        msgbox(sprintf('Saved %d frame(s) to:\n%s', nSlices, outPath), ...
            'NFR - Save Complete');
    end

    function cbScroll(~, evt)
        if isempty(imgRaw) || numFrames <= 1, return; end
        if strcmp(imgType, '3D'), return; end
        newF = curFrame - evt.VerticalScrollCount;
        newF = max(1, min(numFrames, newF));
        if newF == curFrame, return; end
        curFrame = newF;
        set(hSldFrame, 'Value', curFrame);
        set(hLblFrame, 'String', sprintf('Frame: %d / %d', curFrame, numFrames));
        if strcmp(imgType, 'MultiChannel')
            curCh = curFrame;
            set(hPopCh, 'Value', curCh);
            k1 = chK1(curCh);
            k2 = chK2(curCh);
            refreshParamUI();
        end
        doPreview();
        doDisplay();
    end

    function cbResize(~,~)
        if ~ishandle(hFig), return; end
        pos = get(hFig, 'Position');
        W = pos(3);  H = pos(4);
        set(pTop,  'Position', [0, H-TOP_H, W, TOP_H]);
        set(pBot,  'Position', [0, 0, W, BOT_H]);
        set(pMain, 'Position', [0, BOT_H, W, H-TOP_H-BOT_H]);
        set(hSldFrame, 'Position', [145, 154, max(50, W-320), 16]);
        set(hLblCh, 'Position', [W-170, 152, 65, 20]);
        set(hPopCh, 'Position', [W-100, 154, 90, 20]);
    end

    %% ==================================================================
    %%                  3D CROSSHAIR INTERACTION
    %% ==================================================================

    function cb3DClick(src, ~)
        if isempty(imgRaw) || ~strcmp(imgType, '3D'), return; end
        parentAx = get(src, 'Parent');
        cp = get(parentAx, 'CurrentPoint');
        crossX = max(1, min(imgN, round(cp(1,1))));
        crossY = max(1, min(imgM, round(cp(1,2))));
        set(hFig, 'WindowButtonMotionFcn', @cb3DDrag, ...
                   'WindowButtonUpFcn',    @cb3DRelease);
        doDisplay();
    end

    function cb3DDrag(~,~)
        if ~strcmp(imgType, '3D') || isempty(imgRaw), return; end
        try
            cp = get(ax3O_xy, 'CurrentPoint');
            newX = max(1, min(imgN, round(cp(1,1))));
            newY = max(1, min(imgM, round(cp(1,2))));
            if newX ~= crossX || newY ~= crossY
                crossX = newX;
                crossY = newY;
                doDisplay();
            end
        catch
        end
    end

    function cb3DRelease(~,~)
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
    end

    %% ==================================================================
    %%                  CORE NFR ALGORITHM
    %% ==================================================================

    function R = coreNFR2D(img, kk1, kk2)
        I1  = kk1 * img;
        F   = fft2(I1);
        A   = abs(F);
        s1  = sum(A(:));
        AL  = log(kk2 + A);
        AL(AL < 0) = 0;
        s2  = sum(AL(:));
        W   = s1 / s2;
        Ph  = angle(F);
        F2  = W .* AL .* exp(1i .* Ph);
        R   = real(ifft2(F2));
        R(R < 0) = 0;
    end

    function R = coreNFR3D(img, kk1, kk2)
        I1  = kk1 * img;
        F   = fftn(I1);
        A   = abs(F);
        s1  = sum(A(:));
        AL  = log(kk2 + A);
        AL(AL < 0) = 0;
        s2  = sum(AL(:));
        W   = s1 / s2;
        Ph  = angle(F);
        F2  = W .* AL .* exp(1i .* Ph);
        R   = real(ifftn(F2));
        R(R < 0) = 0;
    end

    %% ==================================================================
    %%                  POST-FILTER FUNCTIONS
    %% ==================================================================

    function out = applyFilter2D(img)
    %applyFilter2D  Apply 2D post-filter (Gaussian or disk-Mean)
        r = filterRadius;
        if r <= 0
            out = img;
            return;
        end
        switch lower(filterType)
            case 'gaussian'
                % imgaussfilt uses sigma; here radius = sigma
                out = imgaussfilt(img, r);
            case 'mean'
                % Disk-shaped averaging kernel (circular, not square)
                kernel = fspecial('disk', r);
                out = imfilter(img, kernel, 'replicate');
            otherwise
                out = img;
        end
    end

    function out = applyFilter3D(vol)
    %applyFilter3D  Apply 3D post-filter (Gaussian or sphere-Mean)
        r = filterRadius;
        if r <= 0
            out = vol;
            return;
        end
        switch lower(filterType)
            case 'gaussian'
                % imgaussfilt3 uses sigma; here radius = sigma
                out = imgaussfilt3(vol, r);
            case 'mean'
                % Spherical averaging kernel (ball, not cube)
                ri = ceil(r);
                [gx, gy, gz] = meshgrid(-ri:ri, -ri:ri, -ri:ri);
                mask = double(sqrt(gx.^2 + gy.^2 + gz.^2) <= r);
                if sum(mask(:)) == 0
                    mask = ones(1,1,1);   % safety fallback
                end
                kernel = mask / sum(mask(:));
                out = convn(vol, kernel, 'same');
            otherwise
                out = vol;
        end
    end

    %% ==================================================================
    %%                  PREVIEW & DISPLAY
    %% ==================================================================

    function doPreview()
        if isempty(imgRaw), return; end

        if allProcessed && ~isempty(imgResult)
            switch imgType
                case '2D'
                    previewSlice = imgResult(:,:,1);
                case {'TimeSeries','MultiChannel'}
                    previewSlice = imgResult(:,:, min(curFrame, size(imgResult,3)));
                case '3D'
                    previewSlice = imgResult;
            end
            return;
        end

        tic;
        switch imgType
            case '2D'
                previewSlice = coreNFR2D(imgRaw(:,:,1), k1, k2);
                if filterOn && filterRadius > 0
                    previewSlice = applyFilter2D(previewSlice);
                end
            case 'TimeSeries'
                previewSlice = coreNFR2D(imgRaw(:,:,curFrame), k1, k2);
                if filterOn && filterRadius > 0
                    previewSlice = applyFilter2D(previewSlice);
                end
            case 'MultiChannel'
                previewSlice = coreNFR2D(imgRaw(:,:,curFrame), k1, k2);
                if filterOn && filterRadius > 0
                    previewSlice = applyFilter2D(previewSlice);
                end
            case '3D'
                previewSlice = coreNFR3D(imgRaw, k1, k2);
                if filterOn && filterRadius > 0
                    previewSlice = applyFilter3D(previewSlice);
                end
        end
        procTime = toc;

        filtStr = '';
        if filterOn && filterRadius > 0
            filtStr = sprintf(' + %s r=%.2f', filterType, filterRadius);
        end
        set(hLblTime, 'String', sprintf( ...
            'Preview: %.4f s%s  |  Non-iterative, no PSF, no GPU needed!', ...
            procTime, filtStr));
    end

    function doDisplay()
        if isempty(imgRaw), return; end
        cm = buildColormap(cmapName);

        if strcmp(imgType, '3D')
            render3DMode(cm);
        else
            render2DMode(cm);
        end
    end

    function render2DMode(cm)
        setAxesVisible([ax3O_xy ax3O_yz ax3O_xz ax3P_xy ax3P_yz ax3P_xz], false);

        if strcmp(imgType, '2D')
            origFrame = imgRaw(:,:,1);
        else
            origFrame = imgRaw(:,:, min(curFrame, imgP));
        end

        if ~isempty(previewSlice) && ismatrix(previewSlice)
            procFrame = previewSlice;
        elseif allProcessed && ~isempty(imgResult)
            procFrame = imgResult(:,:, min(curFrame, size(imgResult,3)));
        else
            procFrame = origFrame;
        end

        % Original: auto-contrast
        imagesc(origFrame, 'Parent', ax2D_orig);
        oMin = min(origFrame(:));
        oMax = max(origFrame(:));
        if oMax <= oMin, oMax = oMin + 1; end
        set(ax2D_orig, 'CLim', [oMin oMax]);
        colormap(ax2D_orig, cm);
        axis(ax2D_orig, 'image');
        set(ax2D_orig, 'XTick',[], 'YTick',[], 'Visible','on');
        title(ax2D_orig, sprintf('Original'), 'Color','w', 'FontSize',11);
%         title(ax2D_orig, sprintf('Original  [%.3g, %.3g]', oMin, oMax), ...
%             'Color','w', 'FontSize',11);

        % Processed: auto-contrast
        imagesc(procFrame, 'Parent', ax2D_proc);
        pMin = min(procFrame(:));
        pMax = max(procFrame(:));
        if pMax <= pMin, pMax = pMin + 1; end
        set(ax2D_proc, 'CLim', [pMin pMax]);
        colormap(ax2D_proc, cm);
        axis(ax2D_proc, 'image');
        set(ax2D_proc, 'XTick',[], 'YTick',[], 'Visible','on');
        title(ax2D_proc, sprintf('NFR Result'),'Color','w', 'FontSize',11);
%         title(ax2D_proc, sprintf('NFR Result  [%.3g, %.3g]', pMin, pMax), ...
%             'Color','w', 'FontSize',11);

        linkaxes([ax2D_orig, ax2D_proc], 'xy');
    end

    function render3DMode(cm)
        cla(ax2D_orig); cla(ax2D_proc);
        setAxesVisible([ax2D_orig, ax2D_proc], false);
        setAxesVisible([ax3O_xy ax3O_yz ax3O_xz ax3P_xy ax3P_yz ax3P_xz], true);

        [M, N, P] = size(imgRaw);
        cy = max(1, min(M, crossY));
        cx = max(1, min(N, crossX));

        origMIP = max(imgRaw, [], 3);
        origXZ  = squeeze(imgRaw(cy, :, :))';
        origYZ  = squeeze(imgRaw(:, cx, :));

        if ~isempty(previewSlice) && ndims(previewSlice) == 3
            pData = previewSlice;
        elseif allProcessed && ~isempty(imgResult)
            pData = imgResult;
        else
            pData = imgRaw;
        end
        procMIP = max(pData, [], 3);
        procXZ  = squeeze(pData(cy, :, :))';
        procYZ  = squeeze(pData(:, cx, :));

        showImg(ax3O_xy, origMIP, cm, 'Original MIP (XY)');
        hold(ax3O_xy, 'on');
        plot(ax3O_xy, [cx cx], [0.5, M+0.5], 'y-', 'LineWidth',0.7);
        plot(ax3O_xy, [0.5, N+0.5], [cy cy], 'y-', 'LineWidth',0.7);
        hold(ax3O_xy, 'off');
        ch = get(ax3O_xy, 'Children');
        for ic = 1:numel(ch)
            if strcmp(get(ch(ic),'Type'), 'image')
                set(ch(ic), 'ButtonDownFcn', @cb3DClick, 'HitTest','on');
            end
        end

        showImg(ax3O_xz, origXZ, cm, 'XZ');
        showImg(ax3O_yz, origYZ, cm, 'YZ');

        showImg(ax3P_xy, procMIP, cm, 'NFR MIP (XY)');
        hold(ax3P_xy, 'on');
        plot(ax3P_xy, [cx cx], [0.5, M+0.5], 'y-', 'LineWidth',0.7);
        plot(ax3P_xy, [0.5, N+0.5], [cy cy], 'y-', 'LineWidth',0.7);
        hold(ax3P_xy, 'off');
        ch = get(ax3P_xy, 'Children');
        for ic = 1:numel(ch)
            if strcmp(get(ch(ic),'Type'), 'image')
                set(ch(ic), 'ButtonDownFcn', @cb3DClick, 'HitTest','on');
            end
        end

        showImg(ax3P_xz, procXZ, cm, 'XZ');
        showImg(ax3P_yz, procYZ, cm, 'YZ');

        linkaxes([ax3O_xy, ax3P_xy], 'xy');
        linkaxes([ax3O_xz, ax3P_xz], 'xy');
        linkaxes([ax3O_yz, ax3P_yz], 'xy');
    end

    function showImg(ax, data, cm, titleStr)
        imagesc(data, 'Parent', ax);
        dMin = min(data(:));
        dMax = max(data(:));
        if dMax <= dMin, dMax = dMin + 1; end
        set(ax, 'CLim', [dMin dMax]);
        colormap(ax, cm);
        axis(ax, 'image');
        set(ax, 'XTick',[], 'YTick',[]);
        title(ax, titleStr, 'Color','w', 'FontSize',9);
    end

    %% ==================================================================
    %%                      HELPER FUNCTIONS
    %% ==================================================================

    function syncMultiChParams()
        if strcmp(imgType, 'MultiChannel') && ~isempty(chK1)
            chK1(curCh) = k1;
            chK2(curCh) = k2;
        end
    end

    function refreshParamUI()
        [~, idx1] = min(abs(k1Vals - k1));
        k1Idx = idx1;
        set(hSldK1, 'Value', idx1);
        set(hEdtK1, 'String', formatNum(k1));

        [~, idx2] = min(abs(k2Vals - k2));
        k2Idx = idx2;
        set(hSldK2, 'Value', idx2);
        set(hEdtK2, 'String', formatNum(k2));
    end

    function doReset()
        imgRaw = [];  imgResult = [];  previewSlice = [];
        allProcessed = false;
        curFrame = 1;  numFrames = 1;

        cla(ax2D_orig);  cla(ax2D_proc);
        cla(ax3O_xy); cla(ax3O_xz); cla(ax3O_yz);
        cla(ax3P_xy); cla(ax3P_xz); cla(ax3P_yz);

        set(hSldFrame, 'Min',1, 'Max',2, 'Value',1, 'Enable','off');
        set(hLblFrame, 'String', 'Frame: 1 / 1');
        set(hPopCh, 'Visible','off');
        set(hLblCh, 'Visible','off');
        set(hLblTime, 'String', 'Processing Time:  --');

        setAxesVisible([ax3O_xy ax3O_yz ax3O_xz ax3P_xy ax3P_yz ax3P_xz], false);
        setAxesVisible([ax2D_orig ax2D_proc], true);
    end

    function setAxesVisible(axArray, tf)
        val = boolStr(tf);
        for ii = 1:numel(axArray)
            set(axArray(ii), 'Visible', val);
        end
    end

    function cm = buildColormap(name)
        n = 256;
        switch lower(name)
            case 'gray',    cm = gray(n);
            case 'hot',     cm = hot(n);
            case 'jet',     cm = jet(n);
            case 'parula',  cm = parula(n);
            case 'turbo'
                try cm = turbo(n); catch, cm = jet(n); end
            case 'green'
                cm = [zeros(n,1), linspace(0,1,n)', zeros(n,1)];
            case 'magenta'
                cm = [linspace(0,1,n)', zeros(n,1), linspace(0,1,n)'];
            case 'cyan'
                cm = [zeros(n,1), linspace(0,1,n)', linspace(0,1,n)'];
            otherwise
                cm = gray(n);
        end
    end

    function h = makeLabel(parent, pos, str, col)
        if nargin < 4, col = [0.7 0.7 0.7]; end
        bgc = get(parent, 'BackgroundColor');
        h = uicontrol(parent, 'Style','text', 'String',str, ...
            'Units','pixels', 'Position',pos, ...
            'FontSize',10, 'FontWeight','bold', ...
            'ForegroundColor',col, 'BackgroundColor',bgc, ...
            'HorizontalAlignment','right');
    end

    function s = boolStr(b)
        if b, s = 'on'; else, s = 'off'; end
    end

    function s = formatNum(v)
        if v == 0
            s = '0';
        elseif abs(v) >= 0.01
            s = sprintf('%.4g', v);
        else
            s = sprintf('%.1e', v);
        end
    end

    function showLogo(ax, targetSize)
        try
            lp = fullfile(fileparts(mfilename('fullpath')), 'NFR_logo.png');
            if exist(lp, 'file')
                img = imread(lp);
                [h, w, ~] = size(img);
                sc = targetSize / max(h, w);
                img = imresize(img, sc);
                image(img, 'Parent', ax);
                axis(ax, 'image', 'off');
                return;
            end
        catch
        end
        text(0.5, 0.5, 'NFR', 'Parent', ax, 'Units','normalized', ...
            'HorizontalAlignment','center', 'FontSize',16, ...
            'FontWeight','bold', 'Color',[0 0.9 1]);
        axis(ax, 'off');
    end

    function trySetWindowIcon()
        try
            lp = fullfile(fileparts(mfilename('fullpath')), 'NFR_logo.png');
            if exist(lp, 'file')
                warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved');
                jf = get(hFig, 'JavaFrame'); %#ok<JAVFM>
                jIcon = javax.swing.ImageIcon(lp);
                jf.setFigureIcon(jIcon);
                warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved');
            end
        catch
        end
    end

    %% ====================== Final: Show Figure ======================
    set(hFig, 'ResizeFcn', @cbResize);
    set(hFig, 'Visible', 'on');
    drawnow;

end % End of NFR_GUI