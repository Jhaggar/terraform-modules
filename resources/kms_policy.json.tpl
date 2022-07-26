{
  "Version": "2012-10-17",
  "Id": "sapp-kms-key-policy",
  "Statement": [
    {
      "Sid": "Allow administration of the key",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "kms:*",
      "Resource": "*"
    },
    {
          "Sid": "Allow use of the key",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
             "kms:DescribeKey",
             "kms:Encrypt",
             "kms:Decrypt",
             "kms:ReEncrypt*",
             "kms:GenerateDataKey",
             "kms:GenerateDataKeyWithoutPlaintext"
          ],
          "Resource": "*"
        }
  ]
}