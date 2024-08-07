//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit

class MainTableViewController: UITableViewController {
    let options = ["Init", "Events", "Identify", "DeepLink", "Purchase"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "Cell"
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        
        cell.textLabel?.text = options[indexPath.row]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            let initVC = InitViewController()
            navigationController?.pushViewController(initVC, animated: true)
            break
        case 1:
            let eventsVC = EventViewController()
            navigationController?.pushViewController(eventsVC, animated: true)
            break
        case 2:
            let identifyVC = IdentifyViewController()
            navigationController?.pushViewController(identifyVC, animated: true)
            break
        case 3:
            let deeplinkVC = DeepLinkViewController()
            navigationController?.pushViewController(deeplinkVC, animated: true)
            break
        case 4:
            let purchaseVC = PurchaseViewController()
            navigationController?.pushViewController(purchaseVC, animated: true)
            break
        default:
            break
        }
    }
}

