//
//  ProjectsViewController.swift
//
//
//  Created by MongoDB on 2020-05-04.
//

import Foundation
import UIKit
import RealmSwift

class ProjectsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let tableView = UITableView()
    let userRealm: Realm
    var notificationToken: NotificationToken?
    var userData: User?

    init(userRealm: Realm) {
        self.userRealm = userRealm

        super.init(nibName: nil, bundle: nil)

        // There should only be one user in my realm - that is myself
        let usersInRealm = userRealm.objects(User.self)

        notificationToken = usersInRealm.observe { [weak self, usersInRealm] (changes) in
            self?.userData = usersInRealm.first
            guard let tableView = self?.tableView else { return }
            tableView.reloadData()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // Always invalidate any notification tokens when you are done with them.
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the view.
        title = "Projects"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.frame = self.view.frame
        view.addSubview(tableView)

        // On the top left is a log out button.
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Log Out", style: .plain, target: self, action: #selector(logOutButtonDidClick))
        // NEW//////////////
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addProject))
    }
    
    @objc func addProject(){
        
        try! userRealm.write() {
            let project = Project(partition: "project=\(ObjectId.generate().stringValue)", name: "New Project created")
            guard let user = self.userRealm.object(ofType: User.self, forPrimaryKey: app.currentUser?.id) else { print ("no users"); return}
            user.memberOf.append(project)
            //Add projectpartition to users canwrite and canread array
            addProjectRulesToUser(projectPartition: project.partition!)
        }
    }
    func addProjectRulesToUser(projectPartition: String) {
        print("Adding project: \(projectPartition)")
        let user = app.currentUser!
        user.functions.addProjectRules([AnyBSON(projectPartition)], self.onNewProjectOperationComplete)
    }
    //error handler
        private func onNewProjectOperationComplete(result: AnyBSON?, realmError: Error?) {
            DispatchQueue.main.sync {
                // Always be sure to stop the activity indicator
                //activityIndicator.stopAnimating()

                // There are two kinds of errors:
                // - The Realm function call itself failed (for example, due to network error)
                // - The Realm function call succeeded, but our business logic within the function returned an error,
                //   (for example, user is not a member of the team).
                var errorMessage: String? = nil
                
                if (realmError != nil) {
                    // Error from Realm (failed function call, network error...)
                    errorMessage = realmError!.localizedDescription
                } else if let resultDocument = result?.documentValue {
                    // Check for user error. The addTeamMember function we defined returns an object
                    // with the `error` field set if there was a user error.
                    errorMessage = resultDocument["error"]??.stringValue
                } else {
                    // The function call did not fail but the result was not a document.
                    // This is unexpected.
                    errorMessage = "Unexpected result returned from server"
                }

                // Present error message if any
                guard errorMessage == nil else {
                    print("Adding new project failed: \(errorMessage!)")
                    let alertController = UIAlertController(
                        title: "Error",
                        message: errorMessage!,
                        preferredStyle: .alert
                    );
                    
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
                    present(alertController, animated: true)
                    return
                }
            }
        }

    @objc func logOutButtonDidClick() {
        let alertController = UIAlertController(title: "Log Out", message: "", preferredStyle: .alert);
        alertController.addAction(UIAlertAction(title: "Yes, Log Out", style: .destructive, handler: {
            alert -> Void in
            print("Logging out...");
            app.currentUser?.logOut() { (error) in
                DispatchQueue.main.sync {
                    print("Logged out!");
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // You always have at least one project (your own)
        return userData?.memberOf.count ?? 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.selectionStyle = .none

        // User data may not have loaded yet and no default project
        let projectName = userData?.memberOf[indexPath.row].name //?? "My Project"
        cell.textLabel?.text = projectName
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = app.currentUser!
        let project = userData?.memberOf[indexPath.row]

        Realm.asyncOpen(configuration: user.configuration(partitionValue: (project?.partition)!)) { [weak self] (result) in
            switch result {
            case .failure(let error):
                fatalError("Failed to open realm: \(error)")
            case .success(let realm):
                self?.navigationController?.pushViewController(
                    TasksViewController(realm: realm, title: "\(project!.name!)'s Tasks"),
                    animated: true
                );
            }
        }
    }

}
