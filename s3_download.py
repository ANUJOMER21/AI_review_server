import os
import boto3
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import pytz

# AWS S3 Configuration
s3_config = {
    'bucket': 'caiproduction002',
    'folder': 'original_images',
    'aws_access_key_id': 'AKIA6ODU5IS2B3VHH2YL',
    'aws_secret_access_key': 'Lx79Pt+sb3V3qfFYHUKiOUKWNhS2DNZAv61ebeSZ',
    'region_name': 'us-east-1'
}

output_folder = 'original_validation'
os.makedirs(output_folder, exist_ok=True)

# Set your date range with time as well (format: YYYY-MM-DD HH:MM:SS)
start_date = datetime(2025, 9, 18, 5, 0, 0, tzinfo=pytz.UTC)
end_date = datetime(2025,  9, 18, 7, 0, 0,tzinfo=pytz.UTC)

def connect_s3():
    return boto3.client(
        's3',
        aws_access_key_id=s3_config['aws_access_key_id'],
        aws_secret_access_key=s3_config['aws_secret_access_key'],
        region_name=s3_config['region_name']
    )

def get_image_names(s3_client):
    image_names = []
    paginator = s3_client.get_paginator('list_objects_v2')
    
    for page in paginator.paginate(Bucket=s3_config['bucket'], Prefix=s3_config['folder']):
        for obj in page.get('Contents', []):
            last_modified = obj['LastModified']
            # Check if the last modified date and time is within the specified range
            if start_date <= last_modified <= end_date:
                image_names.append(obj['Key'].replace(s3_config['folder'] + '/', ''))
    return image_names

def download_image(s3_client, image_name):
    image_key = f"{s3_config['folder']}/{image_name}"
    local_image_path = os.path.join(output_folder, image_name)

    if os.path.exists(local_image_path):
        return None  # Skip if the file already exists

    try:
        s3_client.download_file(s3_config['bucket'], image_key, local_image_path)
        return None  # Success
    except Exception as e:
        return f"Failed to download {image_key}: {str(e)}"

def download_images_from_s3():
    s3_client = connect_s3()
    
    image_names = get_image_names(s3_client)

    if not image_names:
        print("No images found in the specified date range.")
        return

    max_workers = 8

    # Using ThreadPoolExecutor for concurrent downloads
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_image = {executor.submit(download_image, s3_client, name): name for name in image_names}

        errors = []
        for future in tqdm(as_completed(future_to_image), total=len(image_names), desc="Downloading images"):
            result = future.result()
            if result is not None:
                errors.append(result)

    if errors:
        print("\nSome errors occurred during the download process:")
        for error in errors:
            print(error)
    else:
        print(f"Image download completed successfully.")

# Call the function to start the download
download_images_from_s3()
