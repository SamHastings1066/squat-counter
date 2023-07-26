//
//  SummaryVC.swift
//  Squat Counter
//
//  Created by sam hastings on 23/07/2023.
//

import UIKit
import RealmSwift

class SummaryVC: UIViewController {
    
    var realmWorkout: RealmWorkout?
    var workoutSets: [RealmSet]?


    //MARK: - IBOutlets
    
    @IBOutlet weak var repsTableView: UITableView!
    
    //MARK: - IBActions
    
    @IBAction func deleteButtonPushed(_ sender: Any) {
        self.performSegue(withIdentifier: "ShowCalendarVC", sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        workoutSets = Array(realmWorkout?.sets ?? List<RealmSet>())

        repsTableView.delegate = self
        repsTableView.dataSource = self
        repsTableView.register(UINib(nibName: K.repCellIdentifier, bundle: nil), forCellReuseIdentifier: K.repCellIdentifier)
    }
}


extension SummaryVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workoutSets!.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: K.repCellIdentifier, for: indexPath) as! RepTableCell
        
        if let workoutSet = workoutSets?[indexPath.row] {
            cell.CellLabel.text = "\(workoutSet.numReps) x \(workoutSet.weight) \(workoutSet.exerciseName ?? "no exercise")s"
        } else {
            cell.textLabel?.text = "No reps counted for this set."
        }
        
        
        return cell
    }
}

extension SummaryVC: UITableViewDelegate {
    // the following method is triggered when a row in the tableview is selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
