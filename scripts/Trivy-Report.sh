cat $1 | jq -r '
  ["ID", "SEVERITY", "PACKAGE", "VERSION", "TITLE"],
  ["--", "--------", "-------", "-------", "-----"],
  (.Results[].Vulnerabilities // [] | .[] | 
    [.VulnerabilityID, .Severity, .PkgName, .InstalledVersion, .Title])
  | @tsv
' | column -t -s $'\t'