//Clear the log window if it was open
	if (isOpen("Log")){
		selectWindow("Log");
		run("Close");
	}
	
//Print the greeting
	print(" ");
	print("Welcome to the ATG8-lipidation assay macro!");
	print(" ");
	print("This macro is desgined for Western Blots containing three bands for each sample:\n\n1. Top  band = Tag-ATG8, \n\n 2. Middle band = Tag-ATG8-PE\n\n 3. Bottom band = free Tag.  \n\nThe macro will caclulate the amount of tagged ATG8-PE, expressed as percent of total tag signal detected in the sample ");
	print(" ");
	print("Please select the folder with images for analysis");
	print(" ");

//Find the original directory and create a new one for quantification results
	original_dir = getDirectory("Select a directory");
	original_folder_name = File.getName(original_dir);
	output_dir = original_dir +"Results" + File.separator;
	File.makeDirectory(output_dir);

//Create the table for all assays results
	Table.create("Assay Results");
	

// Get a list of all the files in the directory
	file_list = getFileList(original_dir);


//Create a shorter list contiaiing .scn files only
	scn_list = newArray(0);
	for(s = 0; s < file_list.length; s++) {
		if(endsWith(file_list[s], ".scn")) { //change to ".tif" when reruning on the results folder
			scn_list = Array.concat(scn_list, file_list[s]);
		}
	}
	
//inform the user about how many images will be analyzed from the selected folder
	print(scn_list.length + " images were detected for analysis");
	print("");

//Loop analysis through the list of .scn files
	for (i = 0; i < scn_list.length; i++){
		path = original_dir + scn_list[i];
		run("Bio-Formats Windowless Importer",  "open=path");    
	
	//Get the image file title and remove the extension from it    
		title = getTitle();
		a = lengthOf(title);
		b = a-4;
		short_name = substring(title, 0, b);
		selectWindow(title);
				
	//Print for the user what image is being processed
		print ("Processing image " + i+1 + " out of " + scn_list.length + ":");
		print(title);
		print("");
		
	//Ask user how to call this quantification
	Assay_title = "AZD";
	Dialog.create("Please enter the name of your quantification");
	Dialog.addString("Assay title", Assay_title);
	Dialog.show();
	Assay_title = Dialog.getString();
	

	//Place the ROIs for each band
		run("ROI Manager...");
		run("Invert"); //use this for .scn files, comment out for tif files
			
	//Wait for the user to crop/rotate the image and save the result
		waitForUser("Please crop and rotate the image if needed. Hit ok to proceed to the Rotate tool");
		run("Rotate... "); 
		saveAs("Tiff", output_dir + Assay_title + short_name + ".tif");
	
	//Make sure ROI Manager is clean of any additional ROIs
		roiManager("reset");
		setTool("rectangle");
		
	//Wait for the user to adjust the ROIs size and position
		waitForUser("Add all ROIs to ROI manager, then hit OK.\n\n1. For each lane select first the GFP-ATG8 band, then the GFP-ATG8-PE band and then free GFP band.\n\n2. Add three ROIs selecting background for GFP-ATG8, GFP-ATG8-PE and free GFP\n\n3. NB! Keep ROI size the same for all selections!\n\n3. Hit ok, when done! "); 
	//Rename the ROIs and save them
			// Initialize sample number
			sample_number = 1;
			
			n = roiManager("count");
			// Loop through the ROIs
			for (r = 0; r < n; r++) {
			    // Select the ROI
			    roiManager("Select", r);
			    
			 // Determine the index within the triplet
			index_in_triplet = (r % 3) + 1; // Adding 1 to start from 1 instead of 0
			    			    
			// Determine the name based on the index within the triplet
		    if (index_in_triplet == 1) {
		        roiManager("Rename", "Tag-ATG8 fusion sample " + sample_number);
		    } else if (index_in_triplet == 2) {
		        roiManager("Rename", "Tag-ATG8-PE sample " + sample_number);
		    } else if (index_in_triplet == 3) {
		        roiManager("Rename", "Free Tag sample " + sample_number);
		        sample_number = sample_number +1;
		    }
		    
		}
			roiManager("Select", n-3);
			roiManager("Rename", "Background signal for Tag-ATG8 fusion");
			roiManager("Select", n-2);
			roiManager("Rename", "Background signal for Tag-ATG8-PE");
			roiManager("Select", n-1);
			roiManager("Rename", "Background signal for free Tag");
			roiManager("Show All with labels");
			roiManager("Save", output_dir + Assay_title + short_name + "_ROIs.zip");
			
			//measure and save IntDen
			run("Invert");
			for ( r=0; r<n; r++ ) {
					run("Clear Results");
				    roiManager("Select", r);
				    ROI_Name = Roi.getName();
				    run("Set Measurements...", "area integrated redirect=None decimal=3");
					roiManager("Measure");
					area = getResult("Area", 0);
					IntDen = getResult("IntDen", 0);
					RawIntDen = getResult("RawIntDen", 0);
					current_last_row = Table.size("Assay Results");
					Table.set("Assay name", current_last_row, Assay_title, "Assay Results");
					Table.set("Band name", current_last_row, ROI_Name, "Assay Results");
					Table.set("Band area", current_last_row, area, "Assay Results");
					Table.set("IntDen", current_last_row, IntDen, "Assay Results");
					Table.set("RawIntDen", current_last_row, RawIntDen, "Assay Results");
					}
				
			//create a column for Integrated density without background
				current_last_row = Table.size("Assay Results");
				Background_for_Tag_ATG8 = Table.get("RawIntDen", current_last_row-3, "Assay Results");
				Background_for_Tag_ATG8_PE = Table.get("RawIntDen", current_last_row-2, "Assay Results");
				Background_for_free_Tag = Table.get("RawIntDen", current_last_row-1, "Assay Results");
								
				for (row = 0; row < current_last_row; row++) {
					Band_name =Table.getString("Band name", row, "Assay Results"); 
					if(indexOf(Band_name, "fusion")>0) {
						 Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
						 IntDen_without_background = Current_RawIntDen - Background_for_Tag_ATG8;
						 } 
					 if(indexOf(Band_name, "PE")>0) {	
						 Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
						 IntDen_without_background = Current_RawIntDen - Background_for_Tag_ATG8_PE;
						 }
					if(indexOf(Band_name, "Free")==0) {	
						 Current_RawIntDen = Table.get("RawIntDen", row, "Assay Results");
						 IntDen_without_background = Current_RawIntDen - Background_for_Tag_ATG8_PE;
						 } 
						 
						 Table.set("RawIntDen_without_background", row, IntDen_without_background, "Assay Results");
				}
				
			//create a column with  sample numbers
				current_last_row = Table.size("Assay Results");
				for (row = 0; row < current_last_row; row++) {
					Band_name =Table.getString("Band name", row, "Assay Results"); 
					Sn_extraction = lastIndexOf(Band_name, "sample");
					 if (Sn_extraction >= 0) {					
						Sample_number = substring(Band_name, Sn_extraction);
					Table.set("Sample number", row, Sample_number, "Assay Results");
				 }
			}
			Table.set("Sample number", current_last_row-3, "","Assay Results"); //clean up the values for the two background rows
			Table.set("Sample number", current_last_row-2, "","Assay Results");
			Table.set("Sample number", current_last_row-1, "","Assay Results");
			
			//create a column with calculation for the Tag-ATG8-PE, expressed as % of all tagged protein detected in the sample
				current_last_row = Table.size("Assay Results");
				for (row = 2; row < current_last_row; row++) {
					Total_Signal = (Table.get("RawIntDen_without_background", row-2, "Assay Results")) + (Table.get("RawIntDen_without_background", row-1, "Assay Results")) + (Table.get("RawIntDen_without_background", row, "Assay Results"));
					Tag_ATG8_PE = Table.get("RawIntDen_without_background", row-1, "Assay Results");
					Tag_ATG8_PE_percent = 100*Tag_ATG8_PE/Total_Signal;
					Table.set("Tag-ATG8-PE as % of cumulative tag signal detected in the sample", row-1, Tag_ATG8_PE_percent, "Assay Results");
					row = row+2;
				 }
			
			//clean up the table  from extra 0 and NaN values
			current_last_row = Table.size("Assay Results");
			for (row = 0; row < current_last_row; row++) {
			    Band_name =Table.getString("Band name", row, "Assay Results");
			    	if(indexOf(Band_name, "fusion")>0) {
					Table.set("Tag-ATG8-PE as % of cumulative tag signal detected in the sample", row, "", "Assay Results");
					}
					if(indexOf(Band_name, "Free")==0) {
					Table.set("Tag-ATG8-PE as % of cumulative tag signal detected in the sample", row, "", "Assay Results");
					}
				}
					Table.set("Tag-ATG8-PE as % of cumulative tag signal detected in the sample", current_last_row-2, "", "Assay Results");	
					Table.set("Tag-ATG8-PE as % of cumulative tag signal detected in the sample", current_last_row-1, "", "Assay Results");			
			
			
			//Save the quantification results into a .csv table file
			if (isOpen("Results")){
			selectWindow("Results");
			run("Close");
			}
			run("Close");
			Table.save(output_dir + "ATG8-lipidation assay results" + ".csv");
			run("Close All");
		}

//A feeble attempt to close those pesky ImageJ windows		
	run("Close All");
	if (isOpen("ROI Manager")){
		selectWindow("ROI Manager");
		run("Close");
	}
	
	
 
//Print the final message
   print(" ");
   print("All Done!");
   print("Your quantification results are saved in the folder " + output_dir);
   print(" "); 
   print(" ");
   print("Alyona Minina. 2024");	
