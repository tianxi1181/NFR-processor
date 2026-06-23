# NFR-processor
NFR provides a deconvolution-like effect to significantly improve image clarity and resolution, but with a revolutionary advantage: **It does not require any knowledge or estimation of the Point Spread Function (PSF)**.
NFR imageJ plugin compatible with Fiji was developed, which enables the application of NFR to 2D images and time-series sequences directly within the ImageJ environment, **without GPU Acceleration**.
Drag NFR_Plugin. jar into the plugin folder of ImageJ, then open ImageJ and find NFR_Plugin in the plugin.☝️We will update the NFR software written in Python that supports 3D data processing in the future☝️.

**Questions, Feedback, or Collaboration**?
We welcome any inquiries regarding NFR. Please feel free to reach out to us at: 12230056@zju.edu.cn.
## ⚠️ Note on Background Noise / Contrast Adjustment
After NFR processing, some images may display a seemingly "dirty" or noisy background. 
This is an **inherent characteristic** of deconvolution and NFR algorithms: the compression of the dynamic range makes previously weak, low-intensity background noise more visible. 
**How to fix it:**
You can easily remove this background by adjusting the display contrast and increasing the minimum threshold (black level). 

* **For example, in ImageJ / Fiji:** Go to `Image` ➔ `Adjust` ➔ `Brightness/Contrast` and increase the **Minimum** slider until the background becomes clean.
## 🎉 NEW: MATLAB GUI for Real-Time Processing
We have updated the NFR MATLAB program with a user-friendly Graphical User Interface (GUI). It is capable of real-time processing **without GPU Acceleration** across various types of datasets. 
Please refer to our instructional image and demo video below, and follow the steps to operate the software.
Instructional image:
<img width="2000" height="1125" alt="How to Use NFR_GUI" src="https://github.com/user-attachments/assets/8b39ec52-db22-487a-93b4-edfa66a0598e" />

Demo video：
https://github.com/user-attachments/assets/be7dcd7c-90bc-4420-9d64-778d010c3595



https://github.com/user-attachments/assets/e23a5190-e28c-496d-9435-ab905e94f28f



https://github.com/user-attachments/assets/b39797a0-c677-4441-b5bf-c59945fc03e5



https://github.com/user-attachments/assets/0970a9a7-f6fe-4b20-8aa8-7d781246b253



https://github.com/user-attachments/assets/6a49e7ec-4761-4602-90b5-3d0f44a2980b

